<?php
// ============================================================
// api/auth.php  –  Login / logout / me
// POST /api/auth.php?action=login   { username, password }
// GET  /api/auth.php?action=me      (Bearer token required)
// ============================================================
require_once __DIR__ . '/config.php';
set_headers();

$action = $_GET['action'] ?? '';

// ── POST /login ──────────────────────────────────────────────
if ($action === 'login' && $_SERVER['REQUEST_METHOD'] === 'POST') {
    $body = json_decode(file_get_contents('php://input'), true) ?? [];
    $username = trim($body['username'] ?? '');
    $password = trim($body['password'] ?? '');

    if (!$username || !$password) json_err('Username and password are required.');

    $stmt = db()->prepare(
        "SELECT u.*, s.id AS student_db_id, s.name AS student_name
           FROM users u
      LEFT JOIN students s ON s.user_id = u.id
          WHERE u.username = ? LIMIT 1"
    );
    $stmt->execute([$username]);
    $user = $stmt->fetch();

    if (!$user || !password_verify($password, $user['password'])) {
        json_err('Invalid credentials.', 401);
    }

    $token = jwt_create([
        'uid'      => $user['id'],
        'username' => $user['username'],
        'role'     => $user['role'],
        'sid'      => $user['student_db_id'],   // null for admin
    ]);

    json_ok([
        'token'    => $token,
        'role'     => $user['role'],
        'username' => $user['username'],
        'name'     => $user['student_name'] ?? $user['username'],
    ]);
}

// ── GET /me ──────────────────────────────────────────────────
if ($action === 'me' && $_SERVER['REQUEST_METHOD'] === 'GET') {
    $claims = require_auth();
    json_ok($claims);
}

json_err('Unknown action.', 404);
