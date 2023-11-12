<?php

include('/usr/src/app/log.php');

$log = new Log();

$requesturi = $_SERVER['REQUEST_URI'];
$time_start = microtime(true);
$log->info("START {$requesturi}");

try {
    crond();
    header("Content-Type: text/plain");
    echo $_ENV['DEPLOY_DATETIME'];
} catch (Exception $ex) {
    $log->warn($ex->getMessage());
}

$log->info('FINISH ' . substr((microtime(true) - $time_start), 0, 7) . 's');

exit();

function crond()
{
    global $log;
    
    $log->info('BEGIN');
    
    if ($_SERVER['HTTP_X_DEPLOY_DATETIME'] != $_ENV['DEPLOY_DATETIME']) {
        $log->warn('VERSION UNMATCH ' . $_SERVER['HTTP_X_DEPLOY_DATETIME']);
        return;
    }
    
    if (check_duplicate() == false) {
        return;
    }
    
    clearstatcache();
    if (!file_exists('/tmp/m_cron.db')) {
        init_sqlite();
    }
    
    $sql_select = <<< __HEREDOC__
SELECT M1.schedule
      ,M1.uri
      ,M1.method
      ,M1.authentication
      ,M1.headers
      ,M1.post_data
  FROM m_cron M1
 ORDER BY M1.uri
__HEREDOC__;
    
    $timestamp = time();
    
    $log->info('cron target time : ' . date('Y/m/d H:i', $timestamp));
    
    $format = [];
    $format[0] = 'i';
    $format[1] = 'H';
    $format[2] = 'd';
    $format[3] = 'm';
    $format[4] = 'D';
    
    $urls = [];
    
    $tasks = [];
    
    $pdo = new PDO('sqlite:/tmp/m_cron.db');

    $statement = $pdo->prepare($sql_select);
    $rc = $statement->execute();
    $results = $statement->fetchAll();

    foreach ($results as $row) {
        $tasks[] = array($row['schedule'], $row['uri'], $row['method'], $row['authentication'], $row['headers'], $row['post_data']);
    }

    $pdo = null;
    
    foreach ($tasks as list($schedules, $uri, $method, $authentication, $headers, $post_data)) {
        $log->info($schedules . ' ' . $uri);
        $schedule = explode(' ', $schedules);
        
        if (count($schedule) != 5) {
            continue;
        }
        
        for ($i = 0; $i < 5; $i++) {
            $is_execute = false;
            $tmp1 = explode(',', $schedule[$i]);
            for ($j = 0; $j < count($tmp1); $j++) {
                if ($tmp1[$j] === '*') {
                    $is_execute = true;
                    break;
                }
                
                if (str_pad($tmp1[$j], 2, '0', STR_PAD_LEFT) === date($format[$i], $timestamp)) {
                    $is_execute = true;
                    break;
                }
                
                if ($i === 4) {
                    continue;
                }
                
                // m-n
                $tmp2 = explode('-', $tmp1[$j]);
                if (count($tmp2) === 2) {
                    $tmp3 = (int)date($format[$i], $timestamp);
                    if ((int)$tmp2[0] <= $tmp3 && $tmp3 <= (int)$tmp2[1]) {
                        $is_execute = true;
                        break;
                    }
                }
                
                // */n
                $tmp2 = explode('*/', $tmp1[$j]);
                if (count($tmp2) === 2) {
                    if ((int)date($format[$i], $timestamp) % (int)$tmp2[1] === 0) {
                        $is_execute = true;
                        break;
                    }
                }
            }
            if ($is_execute === false) {
                break;
            }
        }
        if ($is_execute === false) {
            continue;
        }
        
        // execute
        $options = [
            CURLOPT_TIMEOUT => 30,
            CURLOPT_USERAGENT => date('Y/m/d H:i', $timestamp),
        ];

        if (strlen($headers) > 0) {
            $options += [CURLOPT_HTTPHEADER => unserialize(base64_decode($headers))];
        }
        if (strlen($authentication) > 0) {
            $options += [CURLOPT_USERPWD => base64_encode($authentication)];
        }
        
        if ($method == 'POST') {
            if (strlen($post_data) > 0) {
                $options += [CURLOPT_POST => true,
                             CURLOPT_POSTFIELDS => unserialize(base64_decode($post_data)),
                            ];
            }
        }
        $urls[$uri] = $options;
    }
    
    if (count($urls) == 0) {
        $log->info('NO TARGET');
        return;
    }
    
    $multi_options = [
        CURLMOPT_PIPELINING => CURLPIPE_MULTIPLEX,
        CURLMOPT_MAX_HOST_CONNECTIONS => 20,
        CURLMOPT_MAXCONNECTS => 20,
    ];
    
    $log->info(print_r($urls, true));
    
    get_contents_multi($urls, $multi_options);
}

function check_duplicate()
{
    global $log;

    $log->info('BEGIN');
    
    $time = time();
    
    clearstatcache();
    $lock_file = '/tmp/crond_php_' . date('i', $time);
    if (file_exists($lock_file) == true && ($time - filemtime($lock_file)) < 300) {
        $log->info('EXISTS LOCK FILE');
        return false;
    }
    touch($lock_file);
    
    $pdo = get_pdo();
    
    // $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    $pdo->beginTransaction();
    
    $sql_update = <<< __HEREDOC__
UPDATE m_server
   SET update_time = NOW()
 WHERE server_name = :b_server_name
   AND processed_minute_one_digit = :b_processed_minute_one_digit
   AND update_time < NOW() - INTERVAL 5 MINUTE
__HEREDOC__;
    
    $statement_update = $pdo->prepare($sql_update);
    
    $statement_update->execute([
        ':b_server_name' => $_ENV['RENDER_EXTERNAL_HOSTNAME'],
        ':b_processed_minute_one_digit' => (int)date('i', $time) % 10,
    ]);
    
    if ($statement_update->rowCount() != 1) {
        $pdo->rollBack();
        $pdo = null;
        $log->warn('ROLLBACK');
        return false;
    }
    
    $pdo->commit();
    $pdo = null;
    $log->info('COMMIT');
    return true;
}

function get_pdo()
{
    global $log;

    $log->info('BEGIN');
    
    $dsn = "mysql:host={$_ENV['DB_SERVER']};dbname={$_ENV['DB_NAME']}";
    $options = array(
      PDO::MYSQL_ATTR_SSL_CA => '/etc/ssl/certs/ca-certificates.crt',
    );
    return new PDO($dsn, $_ENV['DB_USER'], $_ENV['DB_PASSWORD'], $options);
}

function init_sqlite()
{
    global $log;

    $log->info('BEGIN');
    
    $pdo_sqlite = new PDO('sqlite:/tmp/m_cron.db');
    
    $log->info('SQLite Version : ' . $pdo_sqlite->query('SELECT sqlite_version()')->fetchColumn());
    
    $sql_create = <<< __HEREDOC__
CREATE TABLE m_cron (
 schedule TEXT,
 uri TEXT,
 method TEXT,
 authentication TEXT,
 headers TEXT,
 post_data TEXT
)
__HEREDOC__;

    $rc = $pdo_sqlite->exec($sql_create);
    $log->info('m_cron create table result : ' . $rc);
    
    $sql_insert = <<< __HEREDOC__
INSERT INTO m_cron VALUES(:b_schedule, :b_uri, :b_method, :b_authentication, :b_headers, :b_post_data)
__HEREDOC__;

    $statement_insert = $pdo_sqlite->prepare($sql_insert);

    $pdo = get_pdo();
    
    $log->info('MySQL Version : ' . $pdo->query('SELECT version()')->fetchColumn());
    
    $sql_select = <<< __HEREDOC__
SELECT M1.schedule
      ,M1.uri
      ,M1.method
      ,M1.authentication
      ,M1.headers
      ,M1.post_data
  FROM m_cron M1
 WHERE M1.enable = TRUE
 ORDER BY M1.uri
__HEREDOC__;

    $statement_select = $pdo->prepare($sql_select);
    $rc = $statement_select->execute();
    $results = $statement_select->fetchAll();
    
    foreach ($results as $row) {
        $statement_insert->execute([
            ':b_schedule' => $row['schedule'],
            ':b_uri' => $row['uri'],
            ':b_method' => $row['method'],
            ':b_authentication' => $row['authentication'],
            ':b_headers' => $row['headers'],
            ':b_post_data' => $row['post_data'],
        ]);
        $log->info('insert result : ' . $statement_insert->rowCount() . ' ' . $row['schedule'] . ' ' . $row['uri']);
    }

    $pdo = null;
    $pdo_sqlite = null;
}

function get_contents_multi($urls_, $multi_options_ = null)
{
    global $log;

    $log->info('BEGIN');

    $time_start = microtime(true);

    if (is_null($urls_)) {
        $urls_ = [];
    }
    
    $mh = curl_multi_init();
    if (is_null($multi_options_) === false) {
        foreach ($multi_options_ as $key => $value) {
            $rc = curl_multi_setopt($mh, $key, $value);
            if ($rc === false) {
                $log->info("curl_multi_setopt : {$key} {$value}");
            }
        }
    }

    foreach ($urls_ as $url => $options_add) {
        $log->info('CURL MULTI Add $url : ' . $url);
        $ch = curl_init();
        $options = [CURLOPT_URL => $url,
                    // CURLOPT_USERAGENT => getenv('USER_AGENT'),
                    CURLOPT_RETURNTRANSFER => true,
                    CURLOPT_ENCODING => '',
                    CURLOPT_FOLLOWLOCATION => true,
                    CURLOPT_MAXREDIRS => 3,
                    CURLOPT_PATH_AS_IS => true,
                    CURLOPT_TCP_FASTOPEN => true,
                    CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_2TLS,
                    CURLOPT_TIMEOUT => 30,
                   ];

        // if (is_null($options_add) === false && array_key_exists(CURLOPT_USERAGENT, $options_add)) {
        //     unset($options[CURLOPT_USERAGENT]);
        // }
        foreach ($options as $key => $value) {
            $rc = curl_setopt($ch, $key, $value);
            if ($rc == false) {
                $log->info("curl_setopt : {$key} {$value}");
            }
        }
        if (is_null($options_add) === false) {
            foreach ($options_add as $key => $value) {
                $rc = curl_setopt($ch, $key, $value);
                if ($rc == false) {
                    $log->info("curl_setopt : {$key} {$value}");
                }
            }
        }
        curl_multi_add_handle($mh, $ch);
        $list_ch[$url] = $ch;
    }

    $active = null;
    $rc = curl_multi_exec($mh, $active);

    $count = 0;
    while ($active && $rc == CURLM_OK) {
        $count++;
        if (curl_multi_select($mh) == -1) {
            usleep(1);
        }
        $rc = curl_multi_exec($mh, $active);
    }
    $log->info('loop count : ' . $count);

    $results = [];
    foreach (array_keys($urls_) as $url) {
        $ch = $list_ch[$url];
        $res = curl_getinfo($ch);
        $http_code = (string)$res['http_code'];
        $log->info("CURL Result {$http_code} : {$url}");
        if ($http_code[0] == '2') {
            $result = curl_multi_getcontent($ch);
            $results[$url] = $result;
        }
        curl_multi_remove_handle($mh, $ch);
        curl_close($ch);
    }

    curl_multi_close($mh);

    $total_time = substr((microtime(true) - $time_start), 0, 7) . 'sec';

    $log->info("Total Time : [{$total_time}]");
    $log->info("memory_get_usage : " . number_format(memory_get_usage()) . 'byte');

    return $results;
}
