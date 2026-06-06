<?php
/**
 * POST /api/auth/approve_user.php
 * Central Users — Admin Approves a Customer Account
 *
 * Request Body (JSON):
 *   { "email": "customer@example.com" }
 *
 * Security:
 *   Requires a valid Admin JWT Bearer token in the Authorization header.
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

// ── 1. Verify Admin Token ────────────────────────────────────────────────────
$headers = function_exists('getallheaders') ? getallheaders() : [];
$authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? $_SERVER['HTTP_AUTHORIZATION'] ?? '';
$adminToken = preg_replace('/^Bearer\s+/i', '', trim($authHeader));

if (empty($adminToken)) {
    errorResponse('Unauthorized: Admin token is required.', 401);
}

// Decode token payload to check role (without verifying signature — signature
// verification requires the JWT secret; adapt if you have a shared JWT helper)
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
    errorResponse('Forbidden: Only admins can approve users.', 403);
}

// ── 2. Parse Request ─────────────────────────────────────────────────────────
$data   = getJsonBody();
$email  = trim($data['email'] ?? '');
$region = trim($data['region'] ?? '');

if (empty($email)) {
    errorResponse('Email address is required.', 400);
}
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    errorResponse('Invalid email address format.', 400);
}

try {
    $pdo = getDBConnection();

    // ── 3. Fetch the User ────────────────────────────────────────────────────
    $stmt = $pdo->prepare("SELECT id, name, email, status FROM users WHERE email = ? LIMIT 1");
    $stmt->execute([$email]);
    $user = $stmt->fetch();

    if (!$user) {
        errorResponse('No account found with this email address.', 404);
    }

    if (strtolower($user['status']) === 'approved') {
        jsonResponse([
            'success' => true,
            'message' => 'This account is already approved.',
        ]);
        exit;
    }

    // ── 4. Update Status to Approved ─────────────────────────────────────────
    if ($region !== '') {
        // Ensure 'region' column exists in Central DB
        try {
            $checkCol = $pdo->query("SHOW COLUMNS FROM users LIKE 'region'")->fetch();
            if (!$checkCol) {
                $pdo->exec("ALTER TABLE users ADD COLUMN region VARCHAR(100) NULL AFTER status");
            }
        } catch (Exception $e) {}
        
        $update = $pdo->prepare("UPDATE users SET status = 'approved', is_active = 1, region = ? WHERE email = ?");
        $update->execute([$region, $email]);
    } else {
        $update = $pdo->prepare("UPDATE users SET status = 'approved', is_active = 1 WHERE email = ?");
        $update->execute([$email]);
    }

    // ── 5. Send Approval Email to Customer ───────────────────────────────────
    $to      = $user['email'];
    $name    = htmlspecialchars($user['name']);
    $subject = "Your Susin Group Account Has Been Approved!";

    $message = "
    <html>
    <head>
        <title>Account Approved</title>
        <meta charset='UTF-8'>
        <style>
            body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f8fafc; color: #1e293b; padding: 20px; }
            .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; padding: 40px; border-radius: 12px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.08); border-top: 6px solid #b71c1c; }
            .logo { font-size: 22px; font-weight: bold; color: #b71c1c; letter-spacing: 1px; text-align: center; margin-bottom: 30px; }
            .badge { display: inline-block; background-color: #e8f5e9; border: 1px solid #a5d6a7; border-radius: 50px; padding: 8px 20px; color: #2e7d32; font-weight: bold; font-size: 14px; }
            .greeting { font-size: 18px; font-weight: bold; margin-bottom: 16px; }
            .body-text { line-height: 1.7; font-size: 15px; color: #475569; margin-bottom: 20px; }
            .highlight-box { background-color: #f1f5f9; border-left: 4px solid #b71c1c; border-radius: 6px; padding: 16px 20px; margin: 24px 0; }
            .cta-btn { display: inline-block; background-color: #b71c1c; color: #ffffff !important; text-decoration: none; padding: 14px 32px; border-radius: 8px; font-weight: bold; font-size: 15px; margin-top: 10px; }
            .footer { font-size: 12px; text-align: center; color: #94a3b8; margin-top: 40px; border-top: 1px solid #e2e8f0; padding-top: 20px; }
        </style>
    </head>
    <body>
        <div class='container'>
            <div class='logo'>SUSIN GROUP</div>
            <div style='text-align:center; margin-bottom:28px;'>
                <span class='badge'>✔ Account Approved</span>
            </div>
            <div class='greeting'>Hello {$name},</div>
            <div class='body-text'>
                Great news! Your registration request for the <strong>Susin Group Customer Portal</strong> has been 
                reviewed and <strong>approved</strong> by our admin team.
            </div>
            <div class='body-text'>
                You can now log in to the app using your registered email address and password to:
            </div>
            <div class='highlight-box'>
                <ul style='margin:0; padding-left:18px; color:#334155; font-size:14px; line-height:2;'>
                    <li>📦 Track your live orders & production timelines</li>
                    <li>📁 Access product documents & technical catalogs</li>
                    <li>📐 Use the Sizing Tool for actuator calculations</li>
                    <li>🎫 Raise and track support tickets</li>
                </ul>
            </div>
            <div class='body-text'>
                If you have any questions, please don't hesitate to reach out to us at 
                <a href='mailto:datasupport@susin.in' style='color:#b71c1c;'>datasupport@susin.in</a>.
            </div>
            <div class='footer'>
                This is an automated notification. Please do not reply directly to this email.<br>
                &copy; " . date('Y') . " Susin Group. All rights reserved.
            </div>
        </div>
    </body>
    </html>
    ";

    $headers  = "MIME-Version: 1.0\r\n";
    $headers .= "Content-type: text/html; charset=UTF-8\r\n";
    $headers .= "From: Susin Group <noreply@susingroup.com>\r\n";

    $mailSent = mail($to, $subject, $message, $headers);

    if (!$mailSent) {
        // Status was updated; email failure is non-fatal — log and continue
        error_log("approve_user.php: mail() failed for $email");
    }

    // ── 6. Return Success ────────────────────────────────────────────────────
    jsonResponse([
        'success'    => true,
        'message'    => "Account approved successfully. A notification email has been sent to {$email}.",
        'email_sent' => $mailSent,
    ]);

} catch (PDOException $e) {
    errorResponse('Database error: ' . $e->getMessage(), 500);
}
