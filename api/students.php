<?php
// ============================================================
// api/students.php  –  Full CRUD for students
//
// GET    /api/students.php              list (search, filter, paginate)
// GET    /api/students.php?id=X         single student
// POST   /api/students.php              create
// PUT    /api/students.php?id=X         update
// DELETE /api/students.php?id=X         delete
// ============================================================
require_once __DIR__ . '/config.php';
set_headers();

$method = $_SERVER['REQUEST_METHOD'];
$id     = isset($_GET['id']) ? (int)$_GET['id'] : null;

// ── Shared columns for SELECT ────────────────────────────────
const SELECT_COLS = "
    s.id, s.student_code, s.name, s.gender, s.age,
    s.dob, s.pob, s.parent_name, s.parent_phone,
    s.course_id, c.name AS course_name, c.score_type,
    s.user_id, u.username, s.status,
    s.created_at, s.updated_at
";

// ── GET list / single ────────────────────────────────────────
if ($method === 'GET') {
    require_auth('admin', 'student', 'parent');

    if ($id) {
        $stmt = db()->prepare("
            SELECT " . SELECT_COLS . "
            FROM students s
            JOIN courses c ON c.id = s.course_id
            LEFT JOIN users u ON u.id = s.user_id
            WHERE s.id = ?
        ");
        $stmt->execute([$id]);
        $row = $stmt->fetch();
        $row ? json_ok($row) : json_err('Student not found.', 404);
    }

    // List with optional search / filter / pagination
    $search   = '%' . trim($_GET['q'] ?? '') . '%';
    $course   = $_GET['course_id'] ?? null;
    $gender   = $_GET['gender'] ?? null;
    $status   = $_GET['status'] ?? 'active';
    $page     = max(1, (int)($_GET['page'] ?? 1));
    $perPage  = max(1, min(100, (int)($_GET['per_page'] ?? 20)));
    $offset   = ($page - 1) * $perPage;

    // Build dynamic WHERE
    $where  = ['1=1'];
    $params = [];

    if (trim($_GET['q'] ?? '')) {
        $where[]  = '(s.name LIKE ? OR s.student_code LIKE ? OR s.parent_name LIKE ?)';
        $params[] = $search; $params[] = $search; $params[] = $search;
    }
    if ($course)     { $where[] = 's.course_id = ?'; $params[] = $course; }
    if ($gender)     { $where[] = 's.gender = ?';    $params[] = $gender; }
    if ($status)     { $where[] = 's.status = ?';    $params[] = $status; }

    $whereSQL = implode(' AND ', $where);

    // Total count
    $countStmt = db()->prepare("
        SELECT COUNT(*) AS total
        FROM students s
        JOIN courses c ON c.id = s.course_id
        LEFT JOIN users u ON u.id = s.user_id
        WHERE $whereSQL
    ");
    $countStmt->execute($params);
    $total = (int)$countStmt->fetchColumn();

    // Data
    $dataStmt = db()->prepare("
        SELECT " . SELECT_COLS . "
        FROM students s
        JOIN courses c ON c.id = s.course_id
        LEFT JOIN users u ON u.id = s.user_id
        WHERE $whereSQL
        ORDER BY s.created_at DESC
        LIMIT $perPage OFFSET $offset
    ");
    $dataStmt->execute($params);
    $rows = $dataStmt->fetchAll();

    json_ok([
        'students'   => $rows,
        'total'      => $total,
        'page'       => $page,
        'per_page'   => $perPage,
        'last_page'  => (int)ceil($total / $perPage),
    ]);
}

// ── POST create ──────────────────────────────────────────────
if ($method === 'POST') {
    require_auth('admin');
    $b = json_decode(file_get_contents('php://input'), true) ?? [];

    // Validation
    $required = ['name','gender','age','dob','pob','parent_name','parent_phone','course_id'];
    foreach ($required as $f) {
        if (empty($b[$f])) json_err("Field '$f' is required.");
    }

    $code = next_student_code();

    // Optional login account
    $userId = null;
    if (!empty($b['username']) && !empty($b['password'])) {
        $hash   = password_hash($b['password'], PASSWORD_BCRYPT, ['cost' => BCRYPT_COST]);
        $uStmt  = db()->prepare(
            "INSERT INTO users (username, password, role) VALUES (?, ?, 'student')"
        );
        $uStmt->execute([$b['username'], $hash]);
        $userId = (int)db()->lastInsertId();
    }

    $stmt = db()->prepare("
        INSERT INTO students
          (student_code, name, gender, age, dob, pob, parent_name, parent_phone, course_id, user_id)
        VALUES (?,?,?,?,?,?,?,?,?,?)
    ");
    $stmt->execute([
        $code, $b['name'], $b['gender'], (int)$b['age'],
        $b['dob'], $b['pob'], $b['parent_name'], $b['parent_phone'],
        (int)$b['course_id'], $userId,
    ]);
    $newId = (int)db()->lastInsertId();

    // Link user → student
    if ($userId) {
        db()->prepare("UPDATE students SET user_id=? WHERE id=?")->execute([$userId, $newId]);
        db()->prepare("UPDATE users SET student_id=? WHERE id=?")->execute([$newId, $userId]);
    }

    // Fetch full row
    $row = db()->prepare("
        SELECT " . SELECT_COLS . "
        FROM students s
        JOIN courses c ON c.id = s.course_id
        LEFT JOIN users u ON u.id = s.user_id
        WHERE s.id = ?
    ");
    $row->execute([$newId]);
    json_ok($row->fetch(), 201);
}

// ── PUT update ───────────────────────────────────────────────
if ($method === 'PUT' && $id) {
    require_auth('admin');
    $b = json_decode(file_get_contents('php://input'), true) ?? [];

    // Check student exists
    $existing = db()->prepare("SELECT * FROM students WHERE id=?")->execute([$id]);

    $fields = [];
    $params = [];
    foreach (['name','gender','age','dob','pob','parent_name','parent_phone','course_id','status'] as $f) {
        if (array_key_exists($f, $b)) {
            $fields[] = "$f = ?";
            $params[] = $b[$f];
        }
    }

    if ($fields) {
        $params[] = $id;
        db()->prepare("UPDATE students SET " . implode(', ', $fields) . " WHERE id=?")->execute($params);
    }

    // Update password if provided
    if (!empty($b['password'])) {
        $stu = db()->prepare("SELECT user_id FROM students WHERE id=?")->execute([$id]);
        $stu = db()->query("SELECT user_id FROM students WHERE id=$id")->fetch();
        if ($stu['user_id']) {
            $hash = password_hash($b['password'], PASSWORD_BCRYPT, ['cost' => BCRYPT_COST]);
            db()->prepare("UPDATE users SET password=? WHERE id=?")->execute([$hash, $stu['user_id']]);
        }
    }

    $row = db()->prepare("
        SELECT " . SELECT_COLS . "
        FROM students s
        JOIN courses c ON c.id = s.course_id
        LEFT JOIN users u ON u.id = s.user_id
        WHERE s.id = ?
    ");
    $row->execute([$id]);
    json_ok($row->fetch());
}

// ── DELETE ───────────────────────────────────────────────────
if ($method === 'DELETE' && $id) {
    require_auth('admin');
    // user will cascade on FK
    $stmt = db()->prepare("SELECT user_id FROM students WHERE id=?");
    $stmt->execute([$id]);
    $row = $stmt->fetch();

    db()->prepare("DELETE FROM students WHERE id=?")->execute([$id]);

    if ($row && $row['user_id']) {
        db()->prepare("DELETE FROM users WHERE id=?")->execute([$row['user_id']]);
    }

    json_ok(['deleted' => true]);
}

json_err('Method not allowed.', 405);
