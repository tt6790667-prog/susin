<?php
/**
 * POST /api/auth/forgot_password.php
 * Central Users — Forgot Password Endpoint
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

$email = trim($data['email']);

// Basic email validation
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    errorResponse('Invalid email address format', 400);
}

try {
    $pdo = getDBConnection();
    
    // 1. Check if user exists in the database
    $stmt = $pdo->prepare("SELECT id, name FROM users WHERE email = ? LIMIT 1");
    $stmt->execute([$email]);
    $user = $stmt->fetch();
    
    if (!$user) {
        // Return error if email not found
        errorResponse('No account found with this email address.', 404);
    }
    
    // 2. Generate a secure, user-friendly 8-character temporary password
    $chars = '23456789abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ'; // Removed confusing chars like 1, l, 0, O
    $tempPassword = '';
    $max = strlen($chars) - 1;
    for ($i = 0; $i < 8; $i++) {
        $tempPassword .= $chars[random_int(0, $max)];
    }
    
    // 3. Hash the temporary password
    $hashedPassword = password_hash($tempPassword, PASSWORD_DEFAULT);
    
    // 4. Update the user's password in the database
    $updateStmt = $pdo->prepare("UPDATE users SET password_hash = ? WHERE email = ?");
    $updateStmt->execute([$hashedPassword, $email]);
    
    // 5. Send Email with the temporary credentials
    $to = $email;
    $subject = "Temporary Password Reset - Susin Group";
    
    // Premium HTML Email Template matching Susin primary red (#B71C1C) brand
    $message = "
    <html>
    <head>
        <title>Temporary Password Reset</title>
        <meta charset='UTF-8'>
        <style>
            body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f8fafc; color: #1e293b; padding: 20px; }
            .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; padding: 40px; border-radius: 12px; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1); border-top: 6px solid #b71c1c; }
            .header { text-align: center; margin-bottom: 30px; }
            .logo { font-size: 24px; font-weight: bold; color: #b71c1c; letter-spacing: 1px; }
            .greeting { font-size: 18px; font-weight: bold; margin-bottom: 20px; }
            .body-text { line-height: 1.6; margin-bottom: 25px; font-size: 15px; color: #475569; }
            .temp-pass-box { background-color: #f1f5f9; border: 1px dashed #cbd5e1; border-radius: 8px; padding: 15px; text-align: center; margin: 25px 0; }
            .temp-password { font-size: 24px; font-weight: bold; font-family: monospace; letter-spacing: 2px; color: #b71c1c; }
            .warning { font-size: 13px; color: #ef4444; border-left: 3px solid #ef4444; padding-left: 10px; margin-top: 20px; }
            .footer { font-size: 12px; text-align: center; color: #94a3b8; margin-top: 40px; border-top: 1px solid #e2e8f0; padding-top: 20px; }
        </style>
    </head>
    <body>
        <div class='container'>
            <div class='header'>
                <div class='logo'>SUSIN GROUP</div>
            </div>
            <div class='greeting'>Hello " . htmlspecialchars($user['name']) . ",</div>
            <div class='body-text'>
                We received a request to reset your password. We have generated a secure temporary password for your account. 
                Use the temporary password below to log in, and make sure to change it in your settings after logging in.
            </div>
            <div class='temp-pass-box'>
                <div class='body-text' style='margin-bottom: 8px; font-size: 13px; font-weight: bold;'>YOUR TEMPORARY PASSWORD:</div>
                <div class='temp-password'>" . $tempPassword . "</div>
            </div>
            <div class='warning'>
                <strong>Important:</strong> For security reasons, please log in and update your password immediately. Do not share this password with anyone.
            </div>
            <div class='footer'>
                This is an automated notification. Please do not reply directly to this email.<br>
                &copy; " . date('Y') . " Susin Group. All rights reserved.
            </div>
        </div>
    </body>
    </html>
    ";
    
    // Set headers for HTML email
    $headers = "MIME-Version: 1.0" . "\r\n";
    $headers .= "Content-type:text/html;charset=UTF-8" . "\r\n";
    $headers .= "From: Susin Auth Service <noreply@susingroup.com>" . "\r\n";
    
    // Send email using standard PHP mail() function
    $mailSent = mail($to, $subject, $message, $headers);
    
    if (!$mailSent) {
        // Fallback or log if mail failed to dispatch
        errorResponse('Password was reset in the database, but email failed to send. Please contact support.', 500);
    }
    
    // Return successful response to the App
    jsonResponse([
        'success' => true,
        'message' => 'A temporary password has been successfully generated and sent to your registered email.'
    ]);
    
} catch (PDOException $e) {
    errorResponse('Database connection failed or query error: ' . $e->getMessage(), 500);
}
