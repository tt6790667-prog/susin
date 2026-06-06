<?php
// Mock the necessary classes and functions to test JWT validation
require_once 'd:/NITHISH/DOCUMENT SOFTWARE/remix-of-remix-of-remix-of-remix-of-asset-navigator-main/api/config/jwt.php';

// Step 1: Login to central users to get a valid token
$ch = curl_init('https://centralusers.susingroup.com/backend-php/api/auth/login.php');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode([
    'email' => 'sales@pmo.com', // wait, let's use the central email
    'password' => 'password123'
]));
$res = curl_exec($ch);
curl_close($ch);

$data = json_decode($res, true);
$token = $data['accessToken'] ?? null;

if (!$token) {
    echo "Login to central users failed: " . $res . "\n";
    exit;
}

echo "Got central token: " . substr($token, 0, 30) . "...\n";

// Step 2: Validate token using the Doc server JWT class
$payload = JWT::validate($token);
if ($payload) {
    echo "Validation Successful!\n";
    print_r($payload);
} else {
    echo "Validation Failed!\n";
    
    // Debug step-by-step
    $parts = explode('.', $token);
    echo "Parts count: " . count($parts) . "\n";
    $payloadData = json_decode(base64_decode(str_replace(['-', '_'], ['+', '/'], $parts[1])), true);
    echo "Payload decoded: ";
    print_r($payloadData);
    
    $base64Header = $parts[0];
    $base64Payload = $parts[1];
    $signature = $parts[2];
    
    $centralSecret = 'central-auth-secret-key-2024';
    $expectedSignatureCentral = hash_hmac('sha256', $base64Header . "." . $base64Payload, $centralSecret, true);
    $base64ExpectedSignatureCentral = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($expectedSignatureCentral));
    
    echo "Signature from token:  " . $signature . "\n";
    echo "Expected Signature:     " . $base64ExpectedSignatureCentral . "\n";
    echo "Signature Match:        " . ($base64ExpectedSignatureCentral === $signature ? "YES" : "NO") . "\n";
}
