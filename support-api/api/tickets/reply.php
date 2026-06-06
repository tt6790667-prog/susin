<?php
/**
 * GET  — list replies for ticket (?ticket_id=uuid)
 * POST — add reply { ticket_id, message }
 */
require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../utils/response.php';
require_once __DIR__ . '/../config/jwt.php';

setCorsHeaders();

$payload = JWT::requireAuth();
$pdo = getDB();

$userId = (string)($payload['user_id'] ?? '');
$userName = $payload['name'] ?? $payload['full_name'] ?? 'User';
$role = strtolower($payload['role'] ?? 'user');
$isAdmin = in_array($role, ['admin', 'gm', 'administrator', 'support'], true);

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $ticketId = $_GET['ticket_id'] ?? '';
    if ($ticketId === '') errorResponse('ticket_id required', 400);

    $t = $pdo->prepare('SELECT user_id FROM support_tickets WHERE id = ?');
    $t->execute([$ticketId]);
    $ticket = $t->fetch();
    if (!$ticket) errorResponse('Ticket not found', 404);
    if (!$isAdmin && $ticket['user_id'] !== $userId) {
        errorResponse('Forbidden', 403);
    }

    $stmt = $pdo->prepare("
        SELECT id, ticket_id AS ticketId, user_id AS userId, user_name AS userName,
               message, attachment,
               DATE_FORMAT(created_at, '%Y-%m-%dT%H:%i:%sZ') AS createdAt
        FROM ticket_replies WHERE ticket_id = ? ORDER BY created_at ASC
    ");
    $stmt->execute([$ticketId]);
    jsonResponse($stmt->fetchAll());
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $raw = json_decode(file_get_contents('php://input'), true) ?? [];
    $ticketId = $raw['ticket_id'] ?? '';
    $message = trim($raw['message'] ?? '');
    if ($ticketId === '' || $message === '') {
        errorResponse('ticket_id and message required', 400);
    }

    $t = $pdo->prepare('SELECT user_id, status FROM support_tickets WHERE id = ?');
    $t->execute([$ticketId]);
    $ticket = $t->fetch();
    if (!$ticket) errorResponse('Ticket not found', 404);
    if (!$isAdmin && $ticket['user_id'] !== $userId) {
        errorResponse('Forbidden', 403);
    }

    $replyId = uuid();
    $stmt = $pdo->prepare("
        INSERT INTO ticket_replies (id, ticket_id, user_id, user_name, message)
        VALUES (?, ?, ?, ?, ?)
    ");
    $stmt->execute([$replyId, $ticketId, $userId, $userName, $message]);

    if ($isAdmin && $ticket['status'] === 'open') {
        $pdo->prepare("UPDATE support_tickets SET status = 'in-progress' WHERE id = ?")
            ->execute([$ticketId]);
    }

    jsonResponse(['message' => 'Reply added', 'id' => $replyId], 201);
}

errorResponse('Method not allowed', 405);
