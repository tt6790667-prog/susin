<?php
class JWT {
    private static $localSecret = null;

    private static function localSecret(): string {
        if (self::$localSecret === null) {
            self::$localSecret = getenv('JWT_SECRET') ?: 'support-portal-local-secret-change-me';
        }
        return self::$localSecret;
    }

    public static function getBearerToken(): string {
        $headers = function_exists('getallheaders') ? getallheaders() : [];
        $auth = $headers['Authorization'] ?? $headers['authorization'] ?? $_SERVER['HTTP_AUTHORIZATION'] ?? '';
        $token = preg_replace('/^Bearer\s+/i', '', trim($auth));
        if (empty($token) && !empty($_GET['token'])) {
            $token = $_GET['token'];
        }
        return $token;
    }

    public static function validate(string $token): ?array {
        $token = trim($token);
        if ($token === '' || $token === 'null') return null;

        $parts = explode('.', $token);
        if (count($parts) !== 3) return null;

        [$h, $p, $s] = $parts;
        $sig = base64_decode(str_replace(['-', '_'], ['+', '/'], $s));
        if (!$sig) return null;

        $payload = json_decode(base64_decode(str_replace(['-', '_'], ['+', '/'], $p)), true);
        if (!$payload || (isset($payload['exp']) && $payload['exp'] < (time() - 300))) {
            return null;
        }

        $secrets = array_merge(
            [self::localSecret()],
            require __DIR__ . '/central_secrets.php'
        );

        $verified = false;
        foreach (array_unique($secrets) as $secret) {
            $expected = hash_hmac('sha256', "$h.$p", $secret, true);
            if (hash_equals($expected, $sig)) {
                $verified = true;
                break;
            }
        }
        if (!$verified) return null;

        if (isset($payload['access']) && is_array($payload['access'])) {
            $host = strtolower($_SERVER['HTTP_HOST'] ?? '');
            $match = null;
            foreach ($payload['access'] as $acc) {
                $domain = strtolower($acc['domain'] ?? '');
                if ($domain && (strpos($host, $domain) !== false || strpos($domain, $host) !== false)) {
                    $match = $acc;
                    break;
                }
            }
            if (!$match && !empty($payload['access'])) {
                $match = $payload['access'][0];
            }
            if ($match) {
                $payload['role'] = $payload['role'] ?? ($match['role'] ?? 'user');
            }
        }

        return $payload;
    }

    public static function requireAuth(): array {
        $token = self::getBearerToken();
        if (!$token) {
            http_response_code(401);
            jsonResponse(['message' => 'Unauthorized'], 401);
        }
        $payload = self::validate($token);
        if (!$payload) {
            http_response_code(401);
            jsonResponse(['message' => 'Invalid or expired token'], 401);
        }
        return $payload;
    }
}
