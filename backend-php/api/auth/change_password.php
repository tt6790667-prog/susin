<?php
/**
 * POST /api/auth/change_password.php
 * Central Users — Change Password Endpoint
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

$data = getJsonBody();

// Validate input
if (empty($data['email'])) {
    errorResponse('Email address is required', 400);
}
if (empty($data['new_password'])) {
    errorResponse('New password is required', 400);
}

$email = trim($data['email']);
$newPassword = $data['new_password'];

if (strlen($newPassword) < 6) {
    errorResponse('New password must be at least 6 characters long', 400);
}

try {
    $pdo = getDBConnection();
    
    // 1. Fetch user by email to verify their identity
    $stmt = $pdo->prepare("SELECT id, name FROM users WHERE email = ? LIMIT 1");
    $stmt->execute([$email]);
    $user = $stmt->fetch();
    
    if (!$user) {
        errorResponse('Account not found.', 404);
    }
    
    // 2. Hash the new password using standard PASSWORD_DEFAULT (bcrypt)
    $hashedPassword = password_hash($newPassword, PASSWORD_DEFAULT);
    
    // 3. Update the password in the database
    $updateStmt = $pdo->prepare("UPDATE users SET password_hash = ? WHERE email = ?");
    $updateStmt->execute([$hashedPassword, $email]);
    
    // Return successful response
    jsonResponse([
        'success' => true,
        'message' => 'Your password has been changed successfully.'
    ]);
    
} catch (PDOException $e) {
    errorResponse('Database query error: ' . $e->getMessage(), 500);
}
