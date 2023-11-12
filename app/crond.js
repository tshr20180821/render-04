// package : cron

const mu = require('./MyUtils.js');
const logger = mu.get_logger();

const https = require("https");
const url = 'https://' + process.env.RENDER_EXTERNAL_HOSTNAME + '/auth/crond.php';
// const fs = require('fs');
const {
    execSync
} = require('child_process');
const mc = (require('memjs')).Client.create()

const CronJob = require('cron').CronJob;

try {
    const job = new CronJob(
        '0 * * * * *',
        function () {
            logger.info('START');

            try {
                var http_options = {
                    method: 'GET',
                    headers: {
                        'Authorization': 'Basic ' + Buffer.from(process.env.BASIC_USER + ':' + process.env.BASIC_PASSWORD).toString('base64'),
                        'User-Agent': 'cron ' + process.env.DEPLOY_DATETIME + ' ' + process.pid,
                        'X-Deploy-DateTime': process.env.DEPLOY_DATETIME
                    }
                };
                http_options.agent = new https.Agent({
                    keepAlive: true
                });

                var data_buffer = [];
                https.request(url, http_options, (res) => {
                    res.on('data', (chunk) => {
                        data_buffer.push(chunk);
                    });
                    res.on('end', () => {
                        logger.info('RESPONSE BODY : ' + Buffer.concat(data_buffer).toString().substring(0, 100));
                        var num = Number(Buffer.concat(data_buffer));
                        if (!Number.isNaN(num) && Number(process.env.DEPLOY_DATETIME) < num) {
                            logger.warn('CRON STOP');
                            this.stop();
                        }
                    });
                    res.on('error', (err) => {
                        logger.warn(err.toString());
                    });

                    logger.info('HTTP STATUS CODE : ' + res.statusCode + ' ' + process.env.RENDER_EXTERNAL_HOSTNAME);

                    if (res.statusCode != 200) {
                        // https://process.env.RENDER_EXTERNAL_HOSTNAME/cdn-cgi/trace
                        mu.send_slack_message('HTTP STATUS CODE : ' + res.statusCode + ' ' + process.env.RENDER_EXTERNAL_HOSTNAME);
                    }
                }).end();
                // check_package_update();
            } catch (err) {
                logger.warn(err.stack);
            }
            // global.gc();
            const memory_usage = process.memoryUsage();
            var message = 'FINISH Heap Total : ' +
                Math.floor(memory_usage.heapTotal / 1024).toLocaleString() +
                'KB Used : ' +
                Math.floor(memory_usage.heapUsed / 1024).toLocaleString() + 'KB';
            logger.info(message);
        },
        null,
        true,
        'Asia/Tokyo'
    );
    job.start();
} catch (err) {
    logger.warn(err.stack);
}

function check_package_update() {
    new Promise((resolve) => {
        try {
            mc.get('CHECK_APT', function (err, val) {
                if (val == null) {
                    mc.set('CHECK_APT', 'dummy', {
                        expires: 10 * 60
                    }, function (err2, rc) {
                        logger.info('memcached set : ' + rc);
                    });
                    var stdout = execSync('apt-get update');
                    logger.info(stdout.toString());
                    stdout = execSync('apt-get -s upgrade | grep upgraded');
                    logger.info(stdout.toString());
                    const dt = new Date();
                    const datetime = dt.getFullYear() + '-' + ('0' + (dt.getMonth() + 1)).slice(-2) + '-' + ('0' + dt.getDate()).slice(-2) + ' ' +
                        ('0' + dt.getHours()).slice(-2) + ':' + ('0' + dt.getMinutes()).slice(-2);
                    mc.set('CHECK_APT', datetime + ' ' + stdout.toString(), {
                        expires: 24 * 60 * 60
                    }, function (err2, rc) {
                        logger.info('memcached set : ' + rc);
                    });
                }
            });

            /*
            const check_apt_file = '/tmp/CHECK_APT';
            if (!fs.existsSync(check_apt_file)) {
                const fd = fs.openSync(check_apt_file, 'w', 0o666);
                fs.writeSync(fd, 'uchecked');
                fs.closeSync(fd);
            }
            logger.info('CHECK APT FILE UPDATE TIME : ' + fs.statSync(check_apt_file).mtime);
            if (((new Date()).getTime() - fs.statSync(check_apt_file).mtimeMs) > 24 * 60 * 60 * 1000) {
                var stdout = execSync('apt-get update');
                logger.info(stdout.toString());
                stdout = execSync('apt-get -s upgrade | grep upgraded');
                logger.info(stdout.toString());
                const fd = fs.openSync(check_apt_file, 'w');
                fs.writeSync(fd, stdout.toString());
                fs.closeSync(fd);
            }
            */
        } catch (err) {
            logger.warn(err.stack);
        }
        resolve();
    });
}
