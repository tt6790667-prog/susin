const http = require('https');

const loginData = JSON.stringify({
  email: 'sales@pmo.com',
  password: 'password123'
});

const loginOptions = {
  hostname: 'gm.susingroup.com',
  path: '/backend-php/api/auth/login.php',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': loginData.length
  }
};

const req = http.request(loginOptions, (res) => {
  let body = '';
  res.on('data', (d) => body += d);
  res.on('end', () => {
    const loginRes = JSON.parse(body);
    const token = loginRes.accessToken;
    
    if (!token) {
        console.log("Login Failed:", body);
        return;
    }

    const orderOptions = {
      hostname: 'gm.susingroup.com',
      path: '/backend-php/api/orders/index.php?limit=1',
      method: 'GET',
      headers: {
        'Authorization': 'Bearer ' + token
      }
    };

    http.get(orderOptions, (res2) => {
      let body2 = '';
      res2.on('data', (d) => body2 += d);
      res2.on('end', () => {
        console.log("REAL DATA KEYS:", Object.keys(JSON.parse(body2).orders[0]));
        console.log("SAMPLE DATA:", JSON.stringify(JSON.parse(body2).orders[0], null, 2));
      });
    });
  });
});

req.on('error', (e) => console.error(e));
req.write(loginData);
req.end();
