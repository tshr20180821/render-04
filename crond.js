require('node-cron').schedule('* * * * *', function() {
  let options = {
    hostname: process.env.SERVER_NAME,
    port: 443,
    // path: '/auth/crond.php',
    path: '/index.html',
    method: 'GET',
    headers: {
      'Authorization': 'Basic ' + Buffer.from(process.env.BASIC_USER + ':' + process.env.BASIC_PASSWORD).toString('base64'),
      'User-Agent': 'node-cron'
    }
  };
  console.error('test1');
  console.error(process.env.SERVER_NAME);
  require('https').request(options).end();
  console.error('test2');
}, {
  scheduled: true,
  timezone: 'Asia/Tokyo'
}).start();
