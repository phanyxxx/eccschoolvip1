<?php
// ============================================================
// api/scores.php  –  Score CRUD + statistics
//
// GET    /api/scores.php?student_id=X     list scores for student
// GET    /api/scores.php?action=stats     dashboard statistics
// POST   /api/scores.php                  add/update score entry
// PUT    /api/scores.php?id=X             update score entry
// DELETE /api/scores.php?id=X             delete score entry
// ============================================================
require_once __DIR__ . '/config.php';
set_headers();

$method = $_SERVER['REQUEST_METHOD'];
$id     = isset($_GET['id']) ? (int)$_GET['id'] : null;
$action = $_GET['action'] ?? '';

// ── Score caps per score_type ────────────────────────────────
const SCORE_CAPS = [
    'bacdub'    => ['homework' => 25, 'monthly_test' => 25],
    'grammar'   => ['attendance' => 5, 'worksheet' => 20, 'monthly_test' => 25],
    'grade6'    => ['attendance' => 5, 'voice_message' => 20, 'monthly_test' => 25],
    'beginner'  => ['attendance' => 5, 'voice_message' => 20, 'monthly_test' => 25],
    'alphabets' => ['attendance' => 5, 'voice_message' => 20, 'monthly_test' => 25],
    'vocabulary'=> ['attendance' => 5, 'worksheet' => 20, 'monthly_test' => 25],
];

function validate_scores(array $b, string $score_type): array {
    $caps   = SCORE_CAPS[$score_type] ?? [];
    $errors = [];
    $clean  = [];
    foreach ($caps as $field => $max) {
        if (array_key_exists($field, $b)) {
            $val = (float)$b[$field];
            if ($val < 0 || $val > $max) {
                $errors[] = "$field must be between 0 and $max.";
            } else {
                $clean[$field] = $val;
            }
        }
    }
    // Fields not applicable for this score_type are forced NULL
    foreach (['attendance','homework','worksheet','voice_message','monthly_test'] as $f) {
        if (!array_key_exists($f, $caps)) $clean[$f] = null;
    }
    return ['errors' => $errors, 'clean' => $clean];
}

// ── GET stats (dashboard) ────────────────────────────────────
if ($method === 'GET' && $action === 'stats') {
    require_auth('admin');

    $pdo = db();

    $stats = [];

    // Total students
    $stats['total_students'] = (int)$pdo->query("SELECT COUNT(*) FROM students WHERE status='active'")->fetchColumn();

    // Average total score
    $stats['avg_score'] = round((float)$pdo->query("
        SELECT AVG(total_score) FROM scores
    ")->fetchColumn(), 1);

    // Grade distribution
    $stats['grade_dist'] = $pdo->query("
        SELECT grade, COUNT(*) AS cnt
        FROM (
            SELECT student_id, grade,
                   ROW_NUMBER() OVER (PARTITION BY student_id ORDER BY created_at DESC) AS rn
            FROM scores
        ) t WHERE rn=1
        GROUP BY grade
    ")->fetchAll();

    // Students per course
    $stats['per_course'] = $pdo->query("
        SELECT c.name AS course, COUNT(s.id) AS cnt
        FROM courses c
        LEFT JOIN students s ON s.course_id = c.id AND s.status='active'
        GROUP BY c.id
    ")->fetchAll();

    // Score trend (last 6 months)
    $stats['score_trend'] = $pdo->query("
        SELECT DATE_FORMAT(created_at,'%b %Y') AS month_label,
               ROUND(AVG(total_score),1)       AS avg_score
        FROM scores
        WHERE created_at >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
        GROUP BY month_label
        ORDER BY MIN(created_at)
    ")->fetchAll();

    // Top 5 students
    $stats['top_students'] = $pdo->query("
        SELECT s.name, s.student_code, c.name AS course, sc.total_score, sc.grade
        FROM students s
        JOIN courses c ON c.id = s.course_id
        JOIN scores  sc ON sc.id = (
            SELECT id FROM scores WHERE student_id=s.id ORDER BY created_at DESC LIMIT 1
        )
        ORDER BY sc.total_score DESC
        LIMIT 5
    ")->fetchAll();

    json_ok($stats);
}

// ── GET list by student ──────────────────────────────────────
if ($method === 'GET' && isset($_GET['student_id'])) {
    require_auth('admin', 'student', 'parent');
    $sid = (int)$_GET['student_id'];

    $rows = db()->prepare("
        SELECT sc.*, u.username AS recorded_by_name
        FROM scores sc
        LEFT JOIN users u ON u.id = sc.recorded_by
        WHERE sc.student_id = ?
        ORDER BY sc.created_at DESC
    ");
    $rows->execute([$sid]);
    json_ok($rows->fetchAll());
}

// ── POST create ──────────────────────────────────────────────
if ($method === 'POST') {
    require_auth('admin');
    $b   = json_decode(file_get_contents('php://input'), true) ?? [];
    $sid = (int)($b['student_id'] ?? 0);

    if (!$sid) json_err('student_id is required.');
    if (empty($b['week_label'])) json_err('week_label is required.');

    // Get score_type from student's course
    $course = db()->prepare("
        SELECT c.score_type FROM students s JOIN courses c ON c.id = s.course_id WHERE s.id=?
    ");
    $course->execute([$sid]);
    $courseRow = $course->fetch();
    if (!$courseRow) json_err('Student not found.', 404);

    $validated = validate_scores($b, $courseRow['score_type']);
    if ($validated['errors']) json_err(implode(' ', $validated['errors']));

    $c     = $validated['clean'];
    $claims = jwt_from_request();

    $stmt = db()->prepare("
        INSERT INTO scores
          (student_id, week_label, attendance, homework, worksheet, voice_message, monthly_test, notes, recorded_by)
        VALUES (?,?,?,?,?,?,?,?,?)
    ");
    $stmt->execute([
        $sid, $b['week_label'],
        $c['attendance'], $c['homework'], $c['worksheet'],
        $c['voice_message'], $c['monthly_test'],
        $b['notes'] ?? null, $claims['uid'] ?? null,
    ]);
    $newId = (int)db()->lastInsertId();

    $row = db()->prepare("SELECT * FROM scores WHERE id=?");
    $row->execute([$newId]);
    json_ok($row->fetch(), 201);
}

// ── PUT update ───────────────────────────────────────────────
if ($method === 'PUT' && $id) {
    require_auth('admin');
    $b = json_decode(file_get_contents('php://input'), true) ?? [];

    // Get score_type
    $stypeRow = db()->query("
        SELECT c.score_type FROM scores sc
        JOIN students s ON s.id=sc.student_id
        JOIN courses c ON c.id=s.course_id
        WHERE sc.id=$id
    ")->fetch();
    if (!$stypeRow) json_err('Score entry not found.', 404);

    $validated = validate_scores($b, $stypeRow['score_type']);
    if ($validated['errors']) json_err(implode(' ', $validated['errors']));

    $c = $validated['clean'];
    $sets = [];
    $params = [];
    if (!is_null($c['attendance']))    { $sets[] = 'attendance=?';    $params[] = $c['attendance']; }
    if (!is_null($c['homework']))      { $sets[] = 'homework=?';      $params[] = $c['homework']; }
    if (!is_null($c['worksheet']))     { $sets[] = 'worksheet=?';     $params[] = $c['worksheet']; }
    if (!is_null($c['voice_message'])) { $sets[] = 'voice_message=?'; $params[] = $c['voice_message']; }
    if (!is_null($c['monthly_test']))  { $sets[] = 'monthly_test=?';  $params[] = $c['monthly_test']; }
    if (array_key_exists('notes', $b)) { $sets[] = 'notes=?'; $params[] = $b['notes']; }
    if (array_key_exists('week_label',$b)){ $sets[]='week_label=?'; $params[]=$b['week_label']; }

    if ($sets) {
        $params[] = $id;
        db()->prepare("UPDATE scores SET " . implode(',',$sets) . " WHERE id=?")->execute($params);
    }

    $row = db()->prepare("SELECT * FROM scores WHERE id=?");
    $row->execute([$id]);
    json_ok($row->fetch());
}

// ── DELETE ───────────────────────────────────────────────────
if ($method === 'DELETE' && $id) {
    require_auth('admin');
    db()->prepare("DELETE FROM scores WHERE id=?")->execute([$id]);
    json_ok(['deleted' => true]);
}

json_err('Method not allowed.', 405);
