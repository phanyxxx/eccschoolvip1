<?php
// ============================================================
// api/attendance.php  –  Daily attendance management
//
// GET  /api/attendance.php?date=YYYY-MM-DD   get all records for a date
// POST /api/attendance.php                   upsert one record
//      body: { student_id, date, status, notes }
// GET  /api/attendance.php?student_id=X      get history for a student
// ============================================================
require_once __DIR__ . '/config.php';
set_headers();

$method = $_SERVER['REQUEST_METHOD'];

// ── GET by date ──────────────────────────────────────────────
if ($method === 'GET' && isset($_GET['date'])) {
    require_auth('admin');
    $date = $_GET['date'];

    // Validate date format
    if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)) {
        json_err('Invalid date format. Use YYYY-MM-DD.');
    }

    // Return all active students with their attendance status for the date
    $stmt = db()->prepare("
        SELECT
            s.id AS student_id,
            s.student_code,
            s.name AS student_name,
            s.gender,
            c.name AS course_name,
            al.id  AS log_id,
            al.status,
            al.notes,
            al.date
        FROM students s
        JOIN courses c ON c.id = s.course_id
        LEFT JOIN attendance_log al ON al.student_id = s.id AND al.date = ?
        WHERE s.status = 'active'
        ORDER BY c.name, s.name
    ");
    $stmt->execute([$date]);
    json_ok($stmt->fetchAll());
}

// ── GET by student ───────────────────────────────────────────
if ($method === 'GET' && isset($_GET['student_id'])) {
    require_auth('admin', 'student', 'parent');
    $sid = (int)$_GET['student_id'];

    $stmt = db()->prepare("
        SELECT * FROM attendance_log
        WHERE student_id = ?
        ORDER BY date DESC
        LIMIT 60
    ");
    $stmt->execute([$sid]);
    json_ok($stmt->fetchAll());
}

// ── GET summary (last 30 days) ───────────────────────────────
if ($method === 'GET' && isset($_GET['action']) && $_GET['action'] === 'summary') {
    require_auth('admin');

    $rows = db()->query("
        SELECT
            s.id AS student_id, s.name AS student_name, s.student_code,
            c.name AS course_name,
            COUNT(CASE WHEN al.status = 'present'  THEN 1 END) AS present,
            COUNT(CASE WHEN al.status = 'absent'   THEN 1 END) AS absent,
            COUNT(CASE WHEN al.status = 'late'     THEN 1 END) AS late,
            COUNT(CASE WHEN al.status = 'excused'  THEN 1 END) AS excused,
            COUNT(al.id) AS total_days
        FROM students s
        JOIN courses c ON c.id = s.course_id
        LEFT JOIN attendance_log al ON al.student_id = s.id
            AND al.date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
        WHERE s.status = 'active'
        GROUP BY s.id, s.name, s.student_code, c.name
        ORDER BY c.name, s.name
    ")->fetchAll();

    json_ok($rows);
}

// ── POST upsert ──────────────────────────────────────────────
if ($method === 'POST') {
    require_auth('admin');
    $b = json_decode(file_get_contents('php://input'), true) ?? [];

    $sid    = (int)($b['student_id'] ?? 0);
    $date   = trim($b['date']   ?? '');
    $status = trim($b['status'] ?? 'present');
    $notes  = trim($b['notes']  ?? '');

    if (!$sid)   json_err('student_id is required.');
    if (!$date)  json_err('date is required.');
    if (!in_array($status, ['present', 'absent', 'late', 'excused'], true)) {
        json_err('status must be present, absent, late, or excused.');
    }

    // UPSERT — update if the record already exists for this student+date
    $stmt = db()->prepare("
        INSERT INTO attendance_log (student_id, date, status, notes)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE status = VALUES(status), notes = VALUES(notes)
    ");
    $stmt->execute([$sid, $date, $status, $notes ?: null]);

    // Return updated row
    $fetch = db()->prepare(
        "SELECT * FROM attendance_log WHERE student_id = ? AND date = ?"
    );
    $fetch->execute([$sid, $date]);
    json_ok($fetch->fetch(), 201);
}

json_err('Method not allowed.', 405);
