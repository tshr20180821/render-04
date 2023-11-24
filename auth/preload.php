<?php

$rc = opcache_compile_file('/usr/src/app/log.php');
error_log("log.php : " . $rc);

$rc = opcache_compile_file('/var/wwww/html/auth/crond.php');
error_log("crond.php : " . $rc);

$rc = opcache_compile_file('/var/wwww/html/auth/health_check.php');
error_log("health_check.php : " . $rc);

$rc = opcache_compile_file('/var/wwww/html/auth/get_dockerhub_repository_information.php');
error_log("get_dockerhub_repository_information.php : " . $rc);

$rc = opcache_compile_file('/var/wwww/html/auth/exec_log_operation.php');
error_log("exec_log_operation.php : " . $rc);

$rc = opcache_compile_file('/var/wwww/html/auth/update_sqlite.php');
error_log("update_sqlite.php : " . $rc);
