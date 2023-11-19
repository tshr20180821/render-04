<?php

include('/usr/src/app/log.php');

$log = new Log();

$requesturi = $_SERVER['REQUEST_URI'];
$time_start = microtime(true);
$log->info("START {$requesturi}");

exec_log_operation();

$log->info('FINISH ' . substr((microtime(true) - $time_start), 0, 7) . 's');

function exec_log_operation()
{
     global $log;
     
     $log->info('BEGIN');

     exec('cd /usr/src/app && java -classpath .:sqlite-jdbc-' . $_ENV['SQLITE_JDBC_VERSION'] . '.jar:slf4j-api-2.0.9.jar:slf4j-nop-2.0.9.jar:LogOperation.jar'
          . ' -Duser.timezone=Asia/Tokyo -Dfile.encoding=UTF-8 LogOperationMain &');
     
     if (file_exists('/tmp/sqlitelog.db') && apcu_exists('SQLITE_VERSION') == false) {
          $pdo = new PDO('sqlite:/tmp/sqlitelog.db', NULL, NULL, array(PDO::ATTR_PERSISTENT => TRUE));

          apcu_store('SQLITE_VERSION', $pdo->query('SELECT sqlite_version()')->fetchColumn());

          $pdo = null;
     }

     if (apcu_exists('last_updated_' . $_ENV['DOCKER_HUB_PHP_TAG']) == false) {
          $url = 'https://' . $_ENV['RENDER_EXTERNAL_HOSTNAME'] . '/auth/get_dockerhub_repository_information.php';
          exec('curl -sS -u ' . $_ENV['BASIC_USER'] . ':' . $_ENV['BASIC_PASSWORD'] . " {$url} &");
     }
}
