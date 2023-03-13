<?php

class Log
{
    $colors = [];
    $colors['INFO'] = '32';
    $colors['WARN'] = '33';
    
    function __construct() {
    }
    
    public function info($message_) {
        $this->output($message_, 'INFO');
    }
    
    public function warn($message_) {
        $this->output($message_, 'WARN');
    }
    
    private function output($message_, $level_, $color_) {
        $array = debug_backtrace();
        array_shift($array);
        if (count($array) == 1) {
            $value = array_shift($array);
            $file = basename($value['file']);
            $line = $value['line'];
            $function_chain = '[-]';
        } else {
            array_shift($array);
            $function_chain = '';
            foreach (array_reverse($array) as $value) {
                $file = basename($value['file']);
                $line = $value['line'];
                $function_chain .= '[' . $value['function'] . ']';
            }
        }
        $log_header = date('Y-m-d H:i:s.') . substr(explode(".", (microtime(true) . ""))[1], 0, 3)
            . ' ' . $_ENV['DEPLOY_DATETIME'] . ' ' . trim(getmypid() . " ${level_} ${file} ${line}");
        file_put_contents('php://stderr', "\033[0;" . $colors[$level_] . "m${log_header}\033[0m ${function_chain} ${message_}\n");
    }
}
