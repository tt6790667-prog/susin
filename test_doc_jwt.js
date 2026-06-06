const crypto = require('crypto');
const https = require('https');

const loginData = JSON.stringify({
  email: 'admin@susingroup.com',
  password: 'admin123'
});

const req = https.request({
  hostname: 'centralusers.susingroup.com',
  path: '/backend-php/api/auth/login.php',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': loginData.length
  }
}, (res) => {
  let body = '';
  res.on('data', (d) => body += d);
  res.on('end', () => {
    const data = JSON.parse(body);
    const token = data.accessToken;
    if (!token) {
      console.log("Login failed:", body);
      return;
    }
    
    console.log("Got token:", token.substring(0, 30) + "...");
    
    // Validate
    const parts = token.split('.');
    const base64Header = parts[0];
    const base64Payload = parts[1];
    const signature = parts[2];
    
    const payloadBuf = Buffer.from(base64Payload.replace(/-/g, '+').replace(/_/g, '/'), 'base64');
    const payload = JSON.parse(payloadBuf.toString());
    console.log("Payload:", payload);
    
    const centralSecret = 'central-auth-secret-key-2024';
    const hmac = crypto.createHmac('sha256', centralSecret);
    hmac.update(base64Header + "." + base64Payload);
    const expectedSigBuf = hmac.digest();
    
    const base64ExpectedSig = expectedSigBuf.toString('base64')
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=/g, '');
      
    console.log("Signature Match:", signature === base64ExpectedSig ? "YES" : "NO");
  });
});

req.on('error', (e) => console.error(e));
req.write(loginData);
req.end();
