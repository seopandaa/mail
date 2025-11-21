<?php

require '/var/email-server/scripts/vendor/autoload.php';
require_once '/var/email-server/scripts/email-sender.php';

class WarmupScheduler {
    private $config;
    private $sender;
    private $logFile;
    private $stateFile;

    public function __construct() {
        $this->config = json_decode(file_get_contents('/var/email-server/config.json'), true);
        $this->sender = new EmailSender();
        $this->logFile = '/var/email-server/logs/warmup-scheduler.log';
        $this->stateFile = '/var/email-server/logs/warmup-state.json';
        $this->ensureLogDirectory();
    }

    private function ensureLogDirectory() {
        $logDir = dirname($this->logFile);
        if (!is_dir($logDir)) {
            mkdir($logDir, 0755, true);
        }
    }

    private function log($message, $level = 'INFO') {
        $timestamp = date('Y-m-d H:i:s');
        $logMessage = "[$timestamp] [$level] $message\n";
        file_put_contents($this->logFile, $logMessage, FILE_APPEND);
        echo $logMessage;
    }

    private function loadState() {
        if (!file_exists($this->stateFile)) {
            return ['last_run_date' => null, 'runs_today' => 0];
        }
        return json_decode(file_get_contents($this->stateFile), true);
    }

    private function saveState($state) {
        file_put_contents($this->stateFile, json_encode($state, JSON_PRETTY_PRINT));
    }

    public function shouldRunNow() {
        if (!$this->config['warmup_schedule']['enabled']) {
            $this->log("Warmup schedule is disabled in config", 'INFO');
            return false;
        }

        $currentTime = date('H:i');
        $scheduledTimes = $this->config['warmup_schedule']['send_times'];
        $tolerance = 5;

        foreach ($scheduledTimes as $scheduledTime) {
            $scheduledTimestamp = strtotime($scheduledTime);
            $currentTimestamp = strtotime($currentTime);
            $diff = abs($currentTimestamp - $scheduledTimestamp) / 60;

            if ($diff <= $tolerance) {
                return true;
            }
        }

        return false;
    }

    public function canRunToday() {
        $state = $this->loadState();
        $today = date('Y-m-d');

        if ($state['last_run_date'] !== $today) {
            $state['last_run_date'] = $today;
            $state['runs_today'] = 0;
            $this->saveState($state);
        }

        $maxRuns = $this->config['warmup_schedule']['emails_per_day'];

        if ($state['runs_today'] >= $maxRuns) {
            $this->log("Already ran $maxRuns times today. Skipping.", 'INFO');
            return false;
        }

        return true;
    }

    public function incrementRunCount() {
        $state = $this->loadState();
        $today = date('Y-m-d');

        if ($state['last_run_date'] !== $today) {
            $state['last_run_date'] = $today;
            $state['runs_today'] = 1;
        } else {
            $state['runs_today']++;
        }

        $this->saveState($state);
    }

    public function run() {
        $this->log("=== Warmup Scheduler Started ===", 'INFO');

        if (!$this->shouldRunNow()) {
            $this->log("Not scheduled to run at this time: " . date('H:i'), 'INFO');
            return false;
        }

        if (!$this->canRunToday()) {
            $this->log("Already reached daily limit", 'INFO');
            return false;
        }

        try {
            $listFile = '/var/email-server/' . $this->config['warmup_schedule']['recipient_list_file'];
            $templateFile = '/var/email-server/' . $this->config['warmup_schedule']['template_file'];

            $this->log("Loading recipients from: $listFile", 'INFO');
            $recipients = $this->sender->loadRecipients($listFile);

            if (empty($recipients)) {
                $this->log("No recipients found in list", 'WARNING');
                return false;
            }

            $this->log("Loaded " . count($recipients) . " recipients", 'INFO');

            $this->log("Loading template from: $templateFile", 'INFO');
            $template = $this->sender->loadTemplate($templateFile);

            $this->log("Starting warmup email campaign", 'INFO');
            $result = $this->sender->sendBulkEmails($recipients, $template);

            $this->log("Campaign completed - Sent: {$result['sent']}, Failed: {$result['failed']}", 'SUCCESS');

            $this->incrementRunCount();
            $state = $this->loadState();
            $this->log("Run count today: {$state['runs_today']}/{$this->config['warmup_schedule']['emails_per_day']}", 'INFO');

            $this->log("=== Warmup Scheduler Finished ===", 'INFO');
            return true;

        } catch (Exception $e) {
            $this->log("Error during warmup campaign: " . $e->getMessage(), 'ERROR');
            return false;
        }
    }

    public function getStatus() {
        $state = $this->loadState();
        $config = $this->config['warmup_schedule'];

        return [
            'enabled' => $config['enabled'],
            'runs_today' => $state['runs_today'],
            'max_runs_per_day' => $config['emails_per_day'],
            'scheduled_times' => $config['send_times'],
            'next_scheduled_time' => $this->getNextScheduledTime(),
            'last_run_date' => $state['last_run_date']
        ];
    }

    private function getNextScheduledTime() {
        $currentTime = time();
        $scheduledTimes = $this->config['warmup_schedule']['send_times'];
        $nextTime = null;

        foreach ($scheduledTimes as $time) {
            $scheduledTimestamp = strtotime($time);
            if ($scheduledTimestamp > $currentTime) {
                $nextTime = $time;
                break;
            }
        }

        if (!$nextTime && !empty($scheduledTimes)) {
            $nextTime = $scheduledTimes[0] . ' (tomorrow)';
        }

        return $nextTime;
    }
}

if (php_sapi_name() === 'cli') {
    try {
        if ($argc < 2) {
            echo "Warmup Scheduler - Usage:\n\n";
            echo "1. Run warmup campaign (check if scheduled):\n";
            echo "   php warmup-scheduler.php run\n\n";
            echo "2. Force run warmup campaign (ignore schedule):\n";
            echo "   php warmup-scheduler.php force\n\n";
            echo "3. Check scheduler status:\n";
            echo "   php warmup-scheduler.php status\n\n";
            exit(1);
        }

        $command = $argv[1];
        $scheduler = new WarmupScheduler();

        switch ($command) {
            case 'run':
                $scheduler->run();
                break;

            case 'force':
                echo "Force running warmup campaign...\n";
                $config = json_decode(file_get_contents('/var/email-server/config.json'), true);
                $sender = new EmailSender();

                $listFile = '/var/email-server/' . $config['warmup_schedule']['recipient_list_file'];
                $templateFile = '/var/email-server/' . $config['warmup_schedule']['template_file'];

                $recipients = $sender->loadRecipients($listFile);
                echo "Loaded " . count($recipients) . " recipients\n";

                $template = $sender->loadTemplate($templateFile);
                $result = $sender->sendBulkEmails($recipients, $template);

                echo "\nResults:\n";
                echo "Sent: {$result['sent']}\n";
                echo "Failed: {$result['failed']}\n";

                $scheduler->incrementRunCount();
                break;

            case 'status':
                $status = $scheduler->getStatus();
                echo "Warmup Scheduler Status:\n";
                echo "=======================\n";
                echo "Enabled: " . ($status['enabled'] ? 'Yes' : 'No') . "\n";
                echo "Runs today: {$status['runs_today']} / {$status['max_runs_per_day']}\n";
                echo "Last run date: " . ($status['last_run_date'] ?? 'Never') . "\n";
                echo "Scheduled times: " . implode(', ', $status['scheduled_times']) . "\n";
                echo "Next scheduled: " . ($status['next_scheduled_time'] ?? 'None') . "\n";
                break;

            default:
                echo "Unknown command: $command\n";
                echo "Use: run, force, or status\n";
                exit(1);
        }

    } catch (Exception $e) {
        echo "Error: " . $e->getMessage() . "\n";
        exit(1);
    }
}
