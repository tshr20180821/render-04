<?php

include('./log.php');

$log = new Log();

$log->trace('message');
$log->debug('message');
$log->info('message');
$log->warn('message');
$log->error('message');
$log->fatal('message');

echo 'test11';

$c = new Test20230310();
$c->test20230310();

exit();

class Test20230310
{
    const LIST_YOBI = array('日', '月', '火', '水', '木', '金', '土');
    
    public function test20230310() {
        $log->warn(LIST_YOBI[0]);
    }
}
