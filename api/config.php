<?php
// ============================================================
// api/config.php  –  Database configuration & helpers
// ============================================================
declare(strict_types=1);

define('DB_HOST', 'localhost');
define('DB_NAME', 'student_management');
define('DB_USER', 'root');           // change in production
define('DB_PASS', '');               // change in production
define('DB_CHARSET', 'utf8mb4');

define('JWT_SECRET', 'change_this_to_a_long_random_string_in_production');
define('BCRYPT_COST', 12);

// ── PDO singleton ────────────────────────────────────────────
function db(): PDO {
    static $pdo = null;
    if ($pdo === null) {
        $dsn = sprintf('mysql:host=%s;dbname=%s;charset=%s', DB_HOST, DB_NAME, DB_CHARSET);
        $pdo = new PDO($dsn, DB_USER, DB_PASS, [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
        ]);
    }
    return $pdo;
}

// ── CORS & JSON headers ──────────────────────────────────────
function set_headers(): void {
    header('Content-Type: application/json; charset=utf-8');
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, Authorization');
    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { exit(0); }
}

// ── JSON response helpers ────────────────────────────────────
function json_ok(mixed $data, int $code = 200): never {
    http_response_code($code);
    echo json_encode(['success' => true, 'data' => $data], JSON_UNESCAPED_UNICODE);
    exit;
}

function json_err(string $msg, int $code = 400): never {
    http_response_code($code);
    echo json_encode(['success' => false, 'error' => $msg], JSON_UNESCAPED_UNICODE);
    exit;
}

// ── JWT (simple HS256) ───────────────────────────────────────
function jwt_create(array $payload): string {
    $header  = base64url_encode(json_encode(['alg'=>'HS256','typ'=>'JWT']));
    $payload['iat'] = time();
    $payload['exp'] = time() + 86400; // 24 h
    $pay = base64url_encode(json_encode($payload));
    $sig = base64url_encode(hash_hmac('sha256', "$header.$pay", JWT_SECRET, true));
    return "$header.$pay.$sig";
}

function jwt_verify(string $token): ?array {
    $parts = explode('.', $token);
    if (count($parts) !== 3) return null;
    [$header, $pay, $sig] = $parts;
    $expected = base64url_encode(hash_hmac('sha256', "$header.$pay", JWT_SECRET, true));
    if (!hash_equals($expected, $sig)) return null;
    $data = json_decode(base64url_decode($pay), true);
    if (!$data || $data['exp'] < time()) return null;
    return $data;
}

function jwt_from_request(): ?array {
    $auth = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (!str_starts_with($auth, 'Bearer ')) return null;
    return jwt_verify(substr($auth, 7));
}

function require_auth(string ...$roles): array {
    $claims = jwt_from_request();
    if (!$claims) json_err('Unauthorized', 401);
    if ($roles && !in_array($claims['role'], $roles, true)) json_err('Forbidden', 403);
    return $claims;
}

// ── Base64url helpers ────────────────────────────────────────
function base64url_encode(string $data): string {
    return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
}
function base64url_decode(string $data): string {
    return base64_decode(strtr($data, '-_', '+/'));
}

// ── Auto-generate student code ───────────────────────────────
function next_student_code(): string {
    $row = db()->query("SELECT MAX(CAST(SUBSTRING(student_code,5) AS UNSIGNED)) AS n FROM students")->fetch();
    $n   = (int)($row['n'] ?? 0) + 1;
    return 'STU-' . str_pad((string)$n, 4, '0', STR_PAD_LEFT);
}
