<?php
function loadEnv($filePath = null) {
    $filePath = $filePath ?? __DIR__ . '/../.env';
    if (!file_exists($filePath)) return false;
    $lines = file($filePath, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
        if (strpos(trim($line), '#') === 0) continue;
        if (strpos($line, '=') === false) continue;
        [$key, $value] = explode('=', $line, 2);
        $key = trim($key);
        $value = trim($value);
        if (!getenv($key)) {
            putenv("$key=$value");
            $_ENV[$key] = $value;
        }
    }
    return true;
}

function env($key, $default = null) {
    $v = getenv($key);
    return ($v === false) ? $default : $v;
}

loadEnv();
