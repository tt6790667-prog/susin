const fs = require('fs');

function checkFile(path) {
  if (!fs.existsSync(path)) {
    console.log(`${path} does not exist`);
    return;
  }
  const stats = fs.statSync(path);
  console.log(`${path} size: ${stats.size} bytes`);
}

checkFile('assets/susin-logo-padded.png');
checkFile('assets/susin-logo-hkea57kH.png');
console.log('Node version:', process.version);
