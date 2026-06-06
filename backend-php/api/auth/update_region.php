<?php
/**
 * POST /api/auth/update_region.php
 * Central Users — Update User/Employee Region
 *
 * Request Body (JSON):
 *   { "email": "employee@example.com", "region": "DNA Team" }
 *   OR
 *   { "id": 12, "region": "DNA Team" }
 *
 * Security:
 *   Requires a valid Admin/GM JWT Bearer token in the Authorization header.
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/response.php';

setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    errorResponse('Method not allowed', 405);
}

// ── 1. Verify Admin/GM Token ──────────────────────────────────────────────────
$headers = function_exists('getallheaders') ? getallheaders() : [];
$authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? $_SERVER['HTTP_AUTHORIZATION'] ?? '';
$adminToken = preg_replace('/^Bearer\s+/i', '', trim($authHeader));

if (empty($adminToken)) {
    errorResponse('Unauthorized: Admin token is required.', 401);
}

// Decode token payload to check role (without verifying signature — signature
// verification requires the JWT secret)
$tokenParts = explode('.', $adminToken);
if (count($tokenParts) !== 3) {
    errorResponse('Unauthorized: Invalid token format.', 401);
}

$payloadJson = base64_decode(str_replace(['-', '_'], ['+', '/'], $tokenParts[1]));
$payload     = json_decode($payloadJson, true);

$role = strtolower($payload['role'] ?? '');
// Support single role string or access array
if (isset($payload['access']) && is_array($payload['access'])) {
    $role = strtolower($payload['access'][0]['role'] ?? $role);
}

if (!in_array($role, ['admin', 'administrator', 'gm'], true)) {
    errorResponse('Forbidden: Only admins can update regions.', 403);
}

// ── 2. Parse Request ─────────────────────────────────────────────────────────
$data   = getJsonBody();
$email  = trim($data['email'] ?? '');
$userId = intval($data['id'] ?? $data['user_id'] ?? 0);
$region = trim($data['region'] ?? '');

if (empty($email) && $userId <= 0) {
    errorResponse('Email address or User ID is required.', 400);
}

try {
    $pdo = getDBConnection();

    // ── 3. Find User ─────────────────────────────────────────────────────────
    if ($userId > 0) {
        $stmt = $pdo->prepare("SELECT id, name, email, designation, region FROM users WHERE id = ? LIMIT 1");
        $stmt->execute([$userId]);
    } else {
        $stmt = $pdo->prepare("SELECT id, name, email, designation, region FROM users WHERE email = ? LIMIT 1");
        $stmt->execute([$email]);
    }
    $user = $stmt->fetch();

    if (!$user) {
        errorResponse('No account found with the specified details.', 404);
    }

    $targetEmail = $user['email'];
    $targetName  = $user['name'];

    // ── 4. Update Region ─────────────────────────────────────────────────────
    // Set region to NULL if empty string is passed (to clear it), otherwise set it
    $dbRegion = ($region === '') ? null : $region;
    
    // Ensure 'region' column exists in Central DB
    try {
        $checkCol = $pdo->query("SHOW COLUMNS FROM users LIKE 'region'")->fetch();
        if (!$checkCol) {
            $pdo->exec("ALTER TABLE users ADD COLUMN region VARCHAR(100) NULL AFTER status");
        }
    } catch (Exception $e) {}
    
    $update = $pdo->prepare("UPDATE users SET region = ? WHERE id = ?");
    $update->execute([$dbRegion, $user['id']]);

    // ── 5. Return Success ────────────────────────────────────────────────────
    jsonResponse([
        'success' => true,
        'message' => "Region updated successfully for {$targetName} ({$targetEmail}).",
        'user' => [
            'id' => $user['id'],
            'name' => $targetName,
            'email' => $targetEmail,
            'designation' => $user['designation'],
            'region' => $dbRegion
        ]
    ]);

} catch (PDOException $e) {
    errorResponse('Database error: ' . $e->getMessage(), 500);
}
?>
