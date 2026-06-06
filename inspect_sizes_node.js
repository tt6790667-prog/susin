const fs = require('fs');

function getPngDimensions(filePath) {
    if (!fs.existsSync(filePath)) {
        console.log(`${filePath} does not exist`);
        return;
    }
    const buffer = fs.readFileSync(filePath);
    // Verify PNG signature
    if (buffer[0] !== 0x89 || buffer[1] !== 0x50 || buffer[2] !== 0x4E || buffer[3] !== 0x47) {
        console.log(`${filePath} is not a valid PNG file`);
        return;
    }
    // Read width and height from IHDR chunk (starts at byte 12, length 4 bytes, type 'IHDR' at 12-15, width at 16-19, height at 20-23)
    const width = buffer.readUInt32BE(16);
    const height = buffer.readUInt32BE(20);
    console.log(`${filePath}: ${width} x ${height} (size: ${buffer.length} bytes)`);
}

getPngDimensions('assets/susin-logo-hkea57kH.png');
getPngDimensions('assets/susin-logo-padded.png');
getPngDimensions('assets/susin-logo-centered.png');
