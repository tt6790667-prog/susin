<?php
/**
 * POST /api/auth/register.php (For App User Signup)
 * GET  /api/auth/register.php (For Email Approve/Reject Actions)
 * Natively integrated with Susin Central Database Architecture
 * Dynamic Auto-Schema Alignment, Email Mailer & One-Click Approval Engine included!
 */
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/response.php';

// ==========================================
// 🔔 CONFIGURATION: Notification Admin Email
// ==========================================
define('ADMIN_NOTIFICATION_EMAIL', 'nithishwipro007@gmail.com');
// ==========================================


// Helper: Beautiful Customer Approval HTML Email dispatch
function sendCustomerApprovalEmail($email, $name) {
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
            .footer { font-size: 12px; text-align: center; color: #94a3b8; margin-top: 40px; border-top: 1px solid #e2e8f0; padding-top: 20px; }
        </style>
    </head>
    <body>
        <div class='container'>
            <div class='logo'>SUSIN GROUP</div>
            <div style='text-align:center; margin-bottom:28px;'>
                <span class='badge'>✔ Account Approved</span>
            </div>
            <div class='greeting'>Hello " . htmlspecialchars($name) . ",</div>
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
    
    @mail($email, $subject, $message, $headers);
}

// Helper: Beautiful Customer Rejection HTML Email dispatch
function sendCustomerRejectionEmail($email, $name) {
    $subject = "Account Registration Status - Susin Group";
    
    $message = "
    <html>
    <head>
        <title>Account Registration Status</title>
        <meta charset='UTF-8'>
        <style>
            body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f8fafc; color: #1e293b; padding: 20px; }
            .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; padding: 40px; border-radius: 12px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.08); border-top: 6px solid #ef4444; }
            .logo { font-size: 22px; font-weight: bold; color: #b71c1c; letter-spacing: 1px; text-align: center; margin-bottom: 30px; }
            .badge { display: inline-block; background-color: #fef2f2; border: 1px solid #fca5a5; border-radius: 50px; padding: 8px 20px; color: #c53030; font-weight: bold; font-size: 14px; }
            .greeting { font-size: 18px; font-weight: bold; margin-bottom: 16px; }
            .body-text { line-height: 1.7; font-size: 15px; color: #475569; margin-bottom: 20px; }
            .footer { font-size: 12px; text-align: center; color: #94a3b8; margin-top: 40px; border-top: 1px solid #e2e8f0; padding-top: 20px; }
        </style>
    </head>
    <body>
        <div class='container'>
            <div class='logo'>SUSIN GROUP</div>
            <div style='text-align:center; margin-bottom:28px;'>
                <span class='badge'>✘ Account Declined</span>
            </div>
            <div class='greeting'>Hello " . htmlspecialchars($name) . ",</div>
            <div class='body-text'>
                Thank you for your interest in registering for the <strong>Susin Group Customer Portal</strong>.
            </div>
            <div class='body-text'>
                After reviewing your registration request, our administrator team has declined access to the portal at this time. 
                This may be due to missing details, incorrect company validation, or policy constraints.
            </div>
            <div class='body-text'>
                If you believe this is an error, or if you would like to clarify details, please feel free to reach out to us at 
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
    
    @mail($email, $subject, $message, $headers);
}

// Custom response template for interactive button actions (Approve / Reject)
function outputActionStatus($title, $message, $isSuccess, $userId = 0, $token = '') {
    $icon = '⚠️';
    $themeColor = '#EF4444';
    
    $extraHtml = '';
    if (strpos($title, 'Approved') !== false) {
        $themeColor = '#22C55E';
        $icon = '✔️';
        if ($userId > 0) {
            // Hardcoded regions (Orders table is in GM DB, not Central DB)
            $optionsHtml = "<option value=''>-- Select Region --</option>";
            $regions = ['DNA Team', 'Special Project Team', 'MRO Team', 'Qatar Team', 'Malaysia', 'UAE', 'Germany', 'Singapore', 'Korea'];
            foreach ($regions as $r) {
                $optionsHtml .= "<option value='$r'>$r</option>";
            }

            $extraHtml = "
            <div style='margin-top: 20px; padding: 20px; background: #F1F5F9; border-radius: 12px; text-align: left; margin-bottom: 24px;'>
                <h3 style='margin-top: 0; font-size: 15px; color: #334155; margin-bottom: 12px;'>Assign a Region (Optional)</h3>
                <form action='register.php' method='GET' style='display: flex; gap: 10px; align-items: center;'>
                    <input type='hidden' name='action' value='assign_region'>
                    <input type='hidden' name='id' value='$userId'>
                    <input type='hidden' name='token' value='$token'>
                    <select name='region' style='flex: 1; padding: 10px; border: 1px solid #CBD5E1; border-radius: 8px; font-size: 14px; outline: none; background: white;'>
                        $optionsHtml
                    </select>
                    <button type='submit' style='padding: 10px 16px; background-color: #0F172A; color: white; border: none; border-radius: 8px; cursor: pointer; font-weight: bold;'>Assign</button>
                </form>
            </div>
            ";
        }
    } else if (strpos($title, 'Rejected') !== false) {
        $themeColor = '#EF4444';
        $icon = '❌';
    }
    
    echo "
    <!DOCTYPE html>
    <html>
    <head>
        <title>$title</title>
        <meta name='viewport' content='width=device-width, initial-scale=1.0'>
        <style>
            body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #F8FAFC; color: #1E293B; margin: 0; padding: 20px; display: flex; align-items: center; justify-content: center; min-height: 100vh; }
            .card { max-width: 500px; width: 100%; background: #FFFFFF; border-radius: 24px; box-shadow: 0 10px 25px -5px rgba(0,0,0,0.1); padding: 40px; border: 1px solid #E2E8F0; text-align: center; }
            .header-logo { font-size: 24px; font-weight: 900; color: #B71C1C; margin-bottom: 24px; letter-spacing: 2px; }
            .icon-wrapper { width: 80px; height: 80px; border-radius: 50%; background-color: {$themeColor}20; display: flex; align-items: center; justify-content: center; margin: 0 auto 24px; font-size: 40px; color: $themeColor; }
            .title { font-size: 22px; font-weight: 800; margin-bottom: 12px; color: #1E293B; }
            .message { font-size: 15px; color: #64748B; line-height: 1.6; margin-bottom: 30px; }
            .btn { display: inline-block; padding: 12px 28px; background-color: #B71C1C; color: white; text-decoration: none; border-radius: 12px; font-weight: 700; font-size: 14px; transition: background-color 0.2s; cursor: pointer; border: none; }
            .btn:hover { background-color: #9E1818; }
        </style>
    </head>
    <body>
        <div class='card'>
            <div class='header-logo'>SUSIN GROUP</div>
            <div class='icon-wrapper'>$icon</div>
            <h1 class='title'>$title</h1>
            <div class='message'>$message</div>
            $extraHtml
            <button onclick='window.close();' class='btn'>Close Tab</button>
        </div>
    </body>
    </html>
    ";
    exit;
}

// ==========================================
// 🛠️ DYNAMIC EMAIL ONE-CLICK ACTIONS HANDLER (GET REQUESTS)
// ==========================================
if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['action'])) {
    $action = $_GET['action'];
    $userId = intval($_GET['id'] ?? 0);
    $token = $_GET['token'] ?? '';
    
    try {
        $pdo = getDBConnection();
        
        // Fetch user data
        $stmt = $pdo->prepare("SELECT name, email FROM users WHERE id = ? LIMIT 1");
        $stmt->execute([$userId]);
        $user = $stmt->fetch();
        
        if (!$user) {
            outputActionStatus("Error", "User not found in system.", false);
        }
        
        // Secure verification token match
        $expectedToken = md5($userId . $user['email'] . 'susin-secret-salt-2026');
        if ($token !== $expectedToken) {
            outputActionStatus("Security Error", "Unauthorized access. Token verification failed.", false);
        }
        
        // Execute dynamic action states
        if ($action === 'approve') {
            // Update to 'approved' and active=1 (aligning with approve_user.php)
            $stmt = $pdo->prepare("UPDATE users SET status = 'approved', is_active = 1 WHERE id = ?");
            $stmt->execute([$userId]);
            
            // Send email to customer BEFORE exiting
            sendCustomerApprovalEmail($user['email'], $user['name']);
            
            outputActionStatus("Access Approved! 🟢", "Customer <strong>" . htmlspecialchars($user['name']) . "</strong> (" . htmlspecialchars($user['email']) . ") has been approved and can now log in to the Susin App immediately.", true, $userId, $token);
        } else if ($action === 'assign_region') {
            $region = $_GET['region'] ?? '';
            $dbRegion = ($region === '') ? null : $region;
            
            // Ensure 'region' column exists in Central DB
            try {
                $checkCol = $pdo->query("SHOW COLUMNS FROM users LIKE 'region'")->fetch();
                if (!$checkCol) {
                    $pdo->exec("ALTER TABLE users ADD COLUMN region VARCHAR(100) NULL AFTER status");
                }
            } catch (Exception $e) {}
            
            $stmt = $pdo->prepare("UPDATE users SET region = ? WHERE id = ?");
            $stmt->execute([$dbRegion, $userId]);
            
            outputActionStatus("Region Assigned! 🟢", "The region <strong>" . htmlspecialchars($region) . "</strong> has been successfully assigned to customer <strong>" . htmlspecialchars($user['name']) . "</strong>. They will now only see orders for this region.", true);
        } else if ($action === 'reject') {
            $stmt = $pdo->prepare("UPDATE users SET status = 'rejected', is_active = 0 WHERE id = ?");
            $stmt->execute([$userId]);
            
            // Send rejection email to customer BEFORE exiting
            sendCustomerRejectionEmail($user['email'], $user['name']);
            
            outputActionStatus("Access Rejected! 🔴", "Customer <strong>" . htmlspecialchars($user['name']) . "</strong> (" . htmlspecialchars($user['email']) . ") has been rejected. Access deactivated successfully.", true);
        } else {
            outputActionStatus("Error", "Invalid action requested.", false);
        }
    } catch (PDOException $e) {
        outputActionStatus("Database Error", "PDO Connection Error: " . $e->getMessage(), false);
    }
}
// ==========================================

// Set standard CORS headers for mobile POST requests
setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    errorResponse('Method not allowed', 405);
}

// Extract JSON payload from App
$data = getJsonBody();
$error = validateRequired($data, ['name', 'email', 'password']);
if ($error) {
    errorResponse($error);
}

// Basic Email Format Validation
if (!filter_var($data['email'], FILTER_VALIDATE_EMAIL)) {
    errorResponse('Invalid email address format', 400);
}

// Helper: Beautiful Interactive HTML Email dispatch trigger for Admin
function sendAdminNotification($userId, $name, $email, $company_name, $phone) {
    $to = ADMIN_NOTIFICATION_EMAIL;
    
    // Subject encoded beautifully for Gmail/Outlook compatibility
    $subject = "=?UTF-8?B?" . base64_encode("🔔 [Susin Portal] New Customer Registration Pending Approval") . "?=";
    
    // Generate secure dynamic links
    $secureToken = md5($userId . $email . 'susin-secret-salt-2026');
    $approveUrl = "https://centralusers.susingroup.com/backend-php/api/auth/register.php?action=approve&id=$userId&token=$secureToken";
    $rejectUrl = "https://centralusers.susingroup.com/backend-php/api/auth/register.php?action=reject&id=$userId&token=$secureToken";
    
    // Premium HTML Email template with interactive action buttons!
    $message = "
    <html>
    <head>
        <title>New Customer Registration</title>
        <style>
            body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; color: #1E293B; background-color: #F8FAFC; margin: 0; padding: 24px; }
            .container { max-width: 600px; background-color: #FFFFFF; border-radius: 16px; border: 1px solid #E2E8F0; padding: 32px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05); margin: 0 auto; }
            .logo-header { text-align: center; border-bottom: 2px solid #F1F5F9; padding-bottom: 20px; margin-bottom: 24px; }
            .logo-text { font-size: 22px; font-weight: 800; color: #B71C1C; letter-spacing: 1.5px; margin: 0; }
            .title { font-size: 18px; font-weight: 700; color: #1E293B; margin-top: 0; margin-bottom: 8px; }
            .subtitle { font-size: 14px; color: #64748B; margin-bottom: 24px; }
            .details-table { width: 100%; border-collapse: collapse; margin-bottom: 28px; }
            .details-table td { padding: 12px 0; border-bottom: 1px solid #F1F5F9; font-size: 14px; }
            .label { font-weight: 700; color: #64748B; width: 35%; text-transform: uppercase; font-size: 11px; letter-spacing: 0.5px; }
            .value { color: #1E293B; font-weight: 600; }
            .btn-container { text-align: center; margin: 32px 0; }
            .btn-approve { display: inline-block; padding: 14px 28px; background-color: #22C55E; color: #FFFFFF !important; text-decoration: none; border-radius: 8px; font-weight: 700; margin-right: 16px; font-size: 13px; letter-spacing: 0.5px; box-shadow: 0 4px 6px rgba(34, 197, 94, 0.2); }
            .btn-reject { display: inline-block; padding: 14px 28px; background-color: #EF4444; color: #FFFFFF !important; text-decoration: none; border-radius: 8px; font-weight: 700; font-size: 13px; letter-spacing: 0.5px; box-shadow: 0 4px 6px rgba(239, 68, 68, 0.2); }
            .action-box { background-color: #FEF2F2; border: 1px solid #FEE2E2; border-radius: 8px; padding: 16px; font-size: 13px; color: #991B1B; font-weight: 600; line-height: 1.5; }
            .footer { text-align: center; font-size: 11px; color: #94A3B8; margin-top: 32px; }
        </style>
    </head>
    <body>
        <div class='container'>
            <div class='logo-header'>
                <p class='logo-text'>SUSIN GROUP</p>
            </div>
            <h2 class='title'>New Customer Registration Received!</h2>
            <p class='subtitle'>A new customer has signed up through the mobile app. You can approve or reject their access directly using the interactive buttons below.</p>
            
            <table class='details-table'>
                <tr>
                    <td class='label'>Full Name</td>
                    <td class='value'>$name</td>
                </tr>
                <tr>
                    <td class='label'>Email Address</td>
                    <td class='value'>$email</td>
                </tr>
                <tr>
                    <td class='label'>Company Name</td>
                    <td class='value'>$company_name</td>
                </tr>
                <tr>
                    <td class='label'>Phone Number</td>
                    <td class='value'>$phone</td>
                </tr>
                <tr>
                    <td class='label'>Submission Time</td>
                    <td class='value'>" . date('Y-m-d H:i:s') . " (Kolkata Time)</td>
                </tr>
            </table>
            
            <div class='btn-container'>
                <a href='$approveUrl' class='btn-approve'>🟢 APPROVE ACCESS</a>
                <a href='$rejectUrl' class='btn-reject'>🔴 REJECT ACCESS</a>
            </div>
            
            <div class='action-box'>
                💡 Fast Actions: Clicking 'APPROVE ACCESS' will change their status to 'approved' instantly in the database, allowing them to login.
            </div>
            
            <div class='footer'>
                This is an automated notification from Susin Central Auth Portal.
            </div>
        </div>
    </body>
    </html>
    ";
    
    // Set headers for HTML email delivery
    $headers = "MIME-Version: 1.0\r\n";
    $headers .= "Content-type: text/html; charset=UTF-8\r\n";
    $headers .= "From: Susin Portal <noreply@susingroup.com>\r\n";
    $headers .= "Reply-To: noreply@susingroup.com\r\n";
    $headers .= "X-Mailer: PHP/" . phpversion() . "\r\n";
    
    // Trigger built-in php mailer safely
    @mail($to, $subject, $message, $headers);
}

try {
    // Dynamic DB connection load
    $pdo = getDBConnection();
    
    // Auto Alter/Alignment
    try {
        $checkCol = $pdo->query("SHOW COLUMNS FROM users LIKE 'company_name'")->fetch();
        if (!$checkCol) {
            $pdo->exec("ALTER TABLE users ADD COLUMN company_name VARCHAR(255) NULL AFTER designation");
        }
        $checkCol = $pdo->query("SHOW COLUMNS FROM users LIKE 'phone'")->fetch();
        if (!$checkCol) {
            $pdo->exec("ALTER TABLE users ADD COLUMN phone VARCHAR(100) NULL AFTER company_name");
        }
        $checkCol = $pdo->query("SHOW COLUMNS FROM users LIKE 'status'")->fetch();
        if (!$checkCol) {
            $pdo->exec("ALTER TABLE users ADD COLUMN status VARCHAR(50) NULL DEFAULT 'pending' AFTER phone");
        }
    } catch (PDOException $schemaEx) {
        // Table modify permissions fallback
    }
    
    // Check if email already registered
    $stmt = $pdo->prepare("SELECT id FROM users WHERE email = ?");
    $stmt->execute([$data['email']]);
    if ($stmt->fetch()) {
        errorResponse('Email address already registered', 400);
    }

    // Secure password hashing
    $hashedPassword = password_hash($data['password'], PASSWORD_DEFAULT);
    
    $designation = 'Customer';
    $company_name = trim($data['company_name'] ?? '');
    $phone = trim($data['phone'] ?? '');
    $userId = 0;

    // Robust Insert Execution
    try {
        $stmt = $pdo->prepare("
            INSERT INTO users (name, email, designation, password_hash, company_name, phone, status, is_active, created_at) 
            VALUES (?, ?, ?, ?, ?, ?, 'pending', 0, NOW())
        ");
        $stmt->execute([
            $data['name'],
            $data['email'],
            $designation,
            $hashedPassword,
            $company_name,
            $phone
        ]);
        $userId = $pdo->lastInsertId();
    } catch (PDOException $ex) {
        if (strpos($ex->getMessage(), 'column') !== false || strpos($ex->getMessage(), 'Unknown') !== false) {
            $stmt = $pdo->prepare("
                INSERT INTO users (name, email, designation, password_hash, status, is_active, created_at) 
                VALUES (?, ?, ?, ?, 'pending', 0, NOW())
            ");
            $stmt->execute([
                $data['name'],
                $data['email'],
                $designation,
                $hashedPassword
            ]);
            $userId = $pdo->lastInsertId();
        } else {
            throw $ex;
        }
    }
    
    // 🔔 SEND EMAIL NOTIFICATION WITH INTERACTIVE ACTION BUTTONS!
    if ($userId > 0) {
        sendAdminNotification($userId, $data['name'], $data['email'], $company_name, $phone);
    }
    
    // Return standard central JSON response
    jsonResponse([
        'success' => true,
        'message' => "User successfully registered. Pending administrator approval.",
        'user' => [
            'name' => $data['name'],
            'email' => $data['email'],
            'company_name' => $company_name,
            'phone' => $phone,
            'status' => 'pending'
        ]
    ], 201);
    
} catch (PDOException $e) {
    errorResponse('Database error: ' . $e->getMessage(), 500);
}
?>
