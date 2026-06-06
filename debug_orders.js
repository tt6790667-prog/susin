const http = require('https');

const req = http.request({
  hostname: 'gm.susingroup.com',
  path: '/backend-php/api/orders/index.php',
  method: 'OPTIONS',
  headers: {
    'Origin': 'http://localhost:53608',
    'Access-Control-Request-Method': 'GET',
    'Access-Control-Request-Headers': 'Authorization,Content-Type'
  }
}, (res) => {
  console.log("HTTP Code:", res.statusCode);
  console.log("Headers:", res.headers);
});

req.on('error', (e) => console.error(e));
req.end();
