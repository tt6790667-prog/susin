<?php
$files = [
    'assets/s.png',
    'assets/susin-logo-hkea57kH.png',
    'assets/susin-logo-padded.png',
    'assets/susin-logo-centered.png'
];
foreach ($files as $file) {
    if (!file_exists($file)) {
        echo "$file : File not found\n";
        continue;
    }
    $info = getimagesize($file);
    echo "$file : " . $info[0] . " x " . $info[1] . " (" . $info['mime'] . ")\n";
}
?>
