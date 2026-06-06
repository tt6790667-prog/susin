<?php
/** Build public URL for files under support-api/uploads/ */
function publicAttachmentUrl(string $path): string {
    $path = trim($path);
    if ($path === '' || strpos($path, 'http') === 0) {
        return $path;
    }
    $base = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? 'https' : 'http')
        . '://' . ($_SERVER['HTTP_HOST'] ?? 'localhost');
    $path = ltrim($path, '/');
    if (strpos($path, 'support-api/') !== 0) {
        $path = 'support-api/' . $path;
    }
    return $base . '/' . $path;
}

function setCorsHeaders(): void {
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: GET, POST, PATCH, DELETE, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, Authorization');
    header('Content-Type: application/json; charset=utf-8');

    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        http_response_code(204);
        exit;
    }
}

function jsonResponse($data, int $code = 200): void {
    if (ob_get_length()) ob_clean();
    http_response_code($code);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

function errorResponse(string $message, int $code = 400): void {
    jsonResponse(['error' => $message, 'message' => $message], $code);
}
