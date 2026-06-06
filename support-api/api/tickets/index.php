<?php
/**
 * Support Tickets API (Susin App)
 * GET  — list tickets (own tickets; admin sees all)
 * POST — create ticket (JSON or multipart + attachment)
 * PATCH — update status (admin only)
 *
 * URL: https://YOUR-SUPPORT-DOMAIN.com/api/tickets/index.php
 */
ini_set('display_errors', '0');
error_reporting(E_ALL);

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../utils/response.php';
require_once __DIR__ . '/../config/jwt.php';

setCorsHeaders();

$payload = JWT::requireAuth();
$pdo = getDB();

$userId = (string)($payload['user_id'] ?? $payload['id'] ?? '');
$userEmail = $payload['email'] ?? '';
$userName = $payload['name'] ?? $payload['full_name'] ?? 'App User';
$role = strtolower($payload['role'] ?? 'user');
$isAdmin = in_array($role, ['admin', 'gm', 'administrator', 'support'], true);

if ($userId === '') {
    errorResponse('Invalid token: missing user_id', 401);
}

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    try {
        if ($isAdmin) {
            $stmt = $pdo->query("
                SELECT id, user_id AS userId, user_email AS userEmail, user_name AS userName,
                       subject, description, status, priority, attachment,
                       DATE_FORMAT(created_at, '%Y-%m-%dT%H:%i:%sZ') AS createdAt,
                       DATE_FORMAT(updated_at, '%Y-%m-%dT%H:%i:%sZ') AS updatedAt
                FROM support_tickets
                ORDER BY created_at DESC
            ");
        } else {
            $stmt = $pdo->prepare("
                SELECT id, user_id AS userId, user_email AS userEmail, user_name AS userName,
                       subject, description, status, priority, attachment,
                       DATE_FORMAT(created_at, '%Y-%m-%dT%H:%i:%sZ') AS createdAt,
                       DATE_FORMAT(updated_at, '%Y-%m-%dT%H:%i:%sZ') AS updatedAt
                FROM support_tickets
                WHERE user_id = ?
                ORDER BY created_at DESC
            ");
            $stmt->execute([$userId]);
        }
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
        $out = [];
        foreach ($rows as $row) {
            if (!empty($row['attachment']) && function_exists('publicAttachmentUrl')) {
                $row['attachment'] = publicAttachmentUrl((string)$row['attachment']);
            } elseif (!empty($row['attachment'])) {
                $path = ltrim((string)$row['attachment'], '/');
                if (strpos($path, 'http') !== 0) {
                    $host = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? 'https' : 'http')
                        . '://' . ($_SERVER['HTTP_HOST'] ?? 'localhost');
                    if (strpos($path, 'support-api/') !== 0) {
                        $path = 'support-api/' . $path;
                    }
                    $row['attachment'] = $host . '/' . $path;
                }
            }
            $row['userRole'] = $isAdmin ? 'admin' : 'user';
            $out[] = $row;
        }
        jsonResponse($out);
    } catch (Throwable $e) {
        error_log('support tickets GET: ' . $e->getMessage());
        errorResponse('Failed to load tickets: ' . $e->getMessage(), 500);
    }
}

if ($method === 'POST') {
    $subject = trim($_POST['subject'] ?? '');
    $description = trim($_POST['description'] ?? '');
    $priority = strtolower($_POST['priority'] ?? 'medium');

    if ($subject === '' || $description === '') {
        $raw = file_get_contents('php://input');
        $json = json_decode($raw, true);
        if (is_array($json)) {
            $subject = trim($json['subject'] ?? '');
            $description = trim($json['description'] ?? '');
            $priority = strtolower($json['priority'] ?? 'medium');
        }
    }

    if ($subject === '' || $description === '') {
        errorResponse('Subject and description are required', 400);
    }

    if (!in_array($priority, ['low', 'medium', 'high', 'urgent'], true)) {
        $priority = 'medium';
    }

    $attachmentPath = null;
    if (isset($_FILES['attachment']) && $_FILES['attachment']['error'] === UPLOAD_ERR_OK) {
        $uploadDir = __DIR__ . '/../../uploads/tickets/';
        if (!is_dir($uploadDir)) {
            mkdir($uploadDir, 0755, true);
        }
        $ext = strtolower(pathinfo($_FILES['attachment']['name'], PATHINFO_EXTENSION));
        $allowed = ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'];
        if (!in_array($ext, $allowed, true)) {
            errorResponse('Invalid file type', 400);
        }
        $fileName = uniqid('ticket_', true) . '.' . $ext;
        if (move_uploaded_file($_FILES['attachment']['tmp_name'], $uploadDir . $fileName)) {
            $attachmentPath = 'uploads/tickets/' . $fileName;
        }
    }

    $id = uuid();
    $stmt = $pdo->prepare("
        INSERT INTO support_tickets
            (id, user_id, user_email, user_name, subject, description, priority, attachment)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ");
    $stmt->execute([
        $id,
        $userId,
        $userEmail,
        $userName,
        $subject,
        $description,
        $priority,
        $attachmentPath,
    ]);

    jsonResponse([
        'message' => 'Ticket submitted successfully',
        'id' => $id,
    ], 201);
}

if ($method === 'PATCH') {
    if (!$isAdmin) {
        errorResponse('Forbidden', 403);
    }
    $raw = json_decode(file_get_contents('php://input'), true);
    $id = $raw['id'] ?? '';
    $status = strtolower($raw['status'] ?? '');
    if ($id === '' || !in_array($status, ['open', 'in-progress', 'resolved'], true)) {
        errorResponse('id and valid status required', 400);
    }
    $stmt = $pdo->prepare('UPDATE support_tickets SET status = ? WHERE id = ?');
    $stmt->execute([$status, $id]);
    jsonResponse(['message' => 'Ticket updated']);
}

errorResponse('Method not allowed', 405);
