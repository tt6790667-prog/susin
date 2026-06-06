const http = require('https');

const req = http.request({
  hostname: 'doc.susingroup.com',
  path: '/api/files/index.php?status=approved',
  method: 'GET'
}, (res) => {
  console.log("HTTP Code:", res.statusCode);
  let body = '';
  res.on('data', (d) => body += d);
  res.on('end', () => {
    console.log("Body:", body);
  });
});

req.on('error', (e) => console.error(e));
req.end();
