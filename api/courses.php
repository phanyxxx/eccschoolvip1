<?php
// ============================================================
// api/courses.php  –  Course management
// GET  /api/courses.php       list all courses
// POST /api/courses.php       create course (admin)
// PUT  /api/courses.php?id=X  update (admin)
// DELETE /api/courses.php?id=X (admin, only if no students)
// ============================================================
require_once __DIR__ . '/config.php';
set_headers();

$method = $_SERVER['REQUEST_METHOD'];
$id     = isset($_GET['id']) ? (int)$_GET['id'] : null;

if ($method === 'GET') {
    require_auth('admin','student','parent');
    $rows = db()->query("SELECT * FROM courses ORDER BY id")->fetchAll();
    json_ok($rows);
}

if ($method === 'POST') {
    require_auth('admin');
    $b = json_decode(file_get_contents('php://input'), true) ?? [];
    if (empty($b['name']))       json_err('name is required.');
    if (empty($b['score_type'])) json_err('score_type is required.');

    $stmt = db()->prepare("INSERT INTO courses (name, score_type, description) VALUES (?,?,?)");
    $stmt->execute([$b['name'], $b['score_type'], $b['description'] ?? null]);
    $newId = (int)db()->lastInsertId();
    $row   = db()->query("SELECT * FROM courses WHERE id=$newId")->fetch();
    json_ok($row, 201);
}

if ($method === 'PUT' && $id) {
    require_auth('admin');
    $b = json_decode(file_get_contents('php://input'), true) ?? [];
    $fields = []; $params = [];
    foreach (['name','score_type','description'] as $f) {
        if (array_key_exists($f, $b)) { $fields[] = "$f=?"; $params[] = $b[$f]; }
    }
    if ($fields) {
        $params[] = $id;
        db()->prepare("UPDATE courses SET ".implode(',',$fields)." WHERE id=?")->execute($params);
    }
    json_ok(db()->query("SELECT * FROM courses WHERE id=$id")->fetch());
}

if ($method === 'DELETE' && $id) {
    require_auth('admin');
    $cnt = (int)db()->query("SELECT COUNT(*) FROM students WHERE course_id=$id")->fetchColumn();
    if ($cnt > 0) json_err("Cannot delete: $cnt student(s) enrolled in this course.");
    db()->prepare("DELETE FROM courses WHERE id=?")->execute([$id]);
    json_ok(['deleted' => true]);
}

json_err('Method not allowed.', 405);
