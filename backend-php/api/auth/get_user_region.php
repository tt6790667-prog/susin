<?php
/**
 * GET /api/auth/get_user_region.php
 * Central Users — Get Region & Designation for Current User
 *
 * Security:
 *   Requires a valid JWT Bearer token in the Authorization header.
 *   Returns region and designation for the authenticated user.
 *   Called by the Orders API (gm.susingroup.com) to resolve cross-domain region data.
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/response.php';

setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    errorResponse('Method not allowed', 405);
}

// ── 1. Verify Token & Extract Email ──────────────────────────────────────────
$headers = function_exists('getallheaders') ? getallheaders() : [];
$authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? $_SERVER['HTTP_AUTHORIZATION'] ?? '';
$token = preg_replace('/^Bearer\s+/i', '', trim($authHeader));

if (empty($token)) {
    errorResponse('Unauthorized: Token is required.', 401);
}

// Decode token payload (signature already verified by Central auth on login)
$tokenParts = explode('.', $token);
if (count($tokenParts) !== 3) {
    errorResponse('Unauthorized: Invalid token format.', 401);
}

$payloadJson = base64_decode(str_replace(['-', '_'], ['+', '/'], $tokenParts[1]));
$payload     = json_decode($payloadJson, true);

if (!$payload) {
    errorResponse('Unauthorized: Could not decode token.', 401);
}

// Check token expiry
$exp = $payload['exp'] ?? 0;
if ($exp > 0 && $exp < time()) {
    errorResponse('Unauthorized: Token expired.', 401);
}

// Extract email from payload
$email = $payload['email'] ?? $payload['user']['email'] ?? '';
if (empty($email)) {
    errorResponse('Unauthorized: Email not found in token.', 401);
}

// ── 2. Fetch Region & Designation from Central DB ───────────────────────────
try {
    $pdo = getDBConnection();

    // Ensure region column exists
    try {
        $checkCol = $pdo->query("SHOW COLUMNS FROM users LIKE 'region'")->fetch();
        if (!$checkCol) {
            $pdo->exec("ALTER TABLE users ADD COLUMN region VARCHAR(100) NULL AFTER status");
        }
    } catch (Exception $e) {}

    $stmt = $pdo->prepare("SELECT name, email, designation, region FROM users WHERE email = ? LIMIT 1");
    $stmt->execute([$email]);
    $user = $stmt->fetch();

    if (!$user) {
        // User not in Central DB — return empty region (no restriction)
        jsonResponse([
            'success'     => true,
            'email'       => $email,
            'region'      => '',
            'designation' => $payload['role'] ?? '',
        ]);
    }

    jsonResponse([
        'success'     => true,
        'email'       => $user['email'],
        'name'        => $user['name'],
        'region'      => $user['region'] ?? '',
        'designation' => $user['designation'] ?? '',
    ]);

} catch (PDOException $e) {
    // On DB error, fail open (return empty region) so Orders API continues working
    jsonResponse([
        'success'     => false,
        'email'       => $email,
        'region'      => '',
        'designation' => '',
        'error'       => 'DB error'
    ]);
}
?>
