<?php

require '/var/email-server/scripts/vendor/autoload.php';

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\SMTP;
use PHPMailer\PHPMailer\Exception;

class EmailSender {
    private $config;
    private $logFile;

    public function __construct($configFile = '/var/email-server/config.json') {
        if (!file_exists($configFile)) {
            throw new Exception("Configuration file not found: $configFile");
        }

        $this->config = json_decode(file_get_contents($configFile), true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            throw new Exception("Invalid JSON in configuration file: " . json_last_error_msg());
        }

        $this->logFile = $this->config['logging']['log_file'] ?? '/var/email-server/logs/email-log.txt';
        $this->ensureLogDirectory();
    }

    private function ensureLogDirectory() {
        $logDir = dirname($this->logFile);
        if (!is_dir($logDir)) {
            mkdir($logDir, 0755, true);
        }
    }

    private function log($message, $level = 'INFO') {
        if (!$this->config['logging']['enabled']) {
            return;
        }

        $timestamp = date('Y-m-d H:i:s');
        $logMessage = "[$timestamp] [$level] $message\n";
        file_put_contents($this->logFile, $logMessage, FILE_APPEND);
    }

    public function loadRecipients($file) {
        if (!file_exists($file)) {
            throw new Exception("Recipient list file not found: $file");
        }

        $lines = file($file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        $recipients = [];

        foreach ($lines as $line) {
            $line = trim($line);
            if (empty($line) || substr($line, 0, 1) === '#') {
                continue;
            }
            if (filter_var($line, FILTER_VALIDATE_EMAIL)) {
                $recipients[] = $line;
            }
        }

        return $recipients;
    }

    public function loadTemplate($file) {
        if (!file_exists($file)) {
            throw new Exception("Template file not found: $file");
        }
        return file_get_contents($file);
    }

    public function replaceVariables($template, $variables) {
        foreach ($variables as $key => $value) {
            $template = str_replace("{{" . strtoupper($key) . "}}", $value, $template);
        }
        return $template;
    }

    public function sendEmail($to, $subject, $htmlBody, $altBody = '') {
        $mail = new PHPMailer(true);

        try {
            $mail->isSMTP();
            $mail->Host = 'localhost';
            $mail->SMTPAuth = false;
            $mail->Port = 25;
            $mail->SMTPDebug = 0;

            $senderEmail = $this->config['email_settings']['sender_email'];
            $senderName = $this->config['email_settings']['sender_name'];
            $replyToEmail = $this->config['email_settings']['reply_to_email'];
            $replyToName = $this->config['email_settings']['reply_to_name'];

            $mail->setFrom($senderEmail, $senderName);
            $mail->addAddress($to);
            $mail->addReplyTo($replyToEmail, $replyToName);

            $mail->isHTML(true);
            $mail->Subject = $subject;
            $mail->Body = $htmlBody;
            $mail->AltBody = $altBody ?: strip_tags($htmlBody);

            $mail->send();
            $this->log("Email sent successfully to: $to | Subject: $subject", 'SUCCESS');
            return ['success' => true, 'message' => 'Email sent successfully'];

        } catch (Exception $e) {
            $this->log("Failed to send email to: $to | Error: {$mail->ErrorInfo}", 'ERROR');
            return ['success' => false, 'message' => $mail->ErrorInfo];
        }
    }

    public function getRandomSubject() {
        $subjects = $this->config['warmup_schedule']['subject_variations'];
        return $subjects[array_rand($subjects)];
    }

    public function sendBulkEmails($recipients, $template, $subject = null, $delaySeconds = null) {
        $delay = $delaySeconds ?? $this->config['rate_limiting']['delay_between_emails_seconds'];
        $maxPerHour = $this->config['rate_limiting']['max_emails_per_hour'];

        $sentCount = 0;
        $failedCount = 0;
        $results = [];

        $this->log("Starting bulk email send to " . count($recipients) . " recipients", 'INFO');

        foreach ($recipients as $index => $recipient) {
            if ($sentCount >= $maxPerHour) {
                $this->log("Reached hourly limit of $maxPerHour emails. Stopping.", 'WARNING');
                break;
            }

            $variables = [
                'company_name' => $this->config['email_settings']['sender_name'],
                'sender_name' => $this->config['email_settings']['sender_name'],
                'sender_email' => $this->config['email_settings']['sender_email'],
                'recipient_email' => $recipient,
                'current_year' => date('Y')
            ];

            $htmlBody = $this->replaceVariables($template, $variables);

            $emailSubject = $subject;
            if ($this->config['warmup_schedule']['random_subject'] && !$subject) {
                $emailSubject = $this->getRandomSubject();
            }

            $result = $this->sendEmail($recipient, $emailSubject, $htmlBody);
            $results[] = [
                'recipient' => $recipient,
                'success' => $result['success'],
                'message' => $result['message']
            ];

            if ($result['success']) {
                $sentCount++;
            } else {
                $failedCount++;
            }

            if ($index < count($recipients) - 1) {
                sleep($delay);
            }
        }

        $this->log("Bulk send completed. Sent: $sentCount, Failed: $failedCount", 'INFO');

        return [
            'total' => count($recipients),
            'sent' => $sentCount,
            'failed' => $failedCount,
            'results' => $results
        ];
    }
}

if (php_sapi_name() === 'cli') {
    try {
        $sender = new EmailSender();

        if ($argc < 2) {
            echo "Email Sender - Usage:\n\n";
            echo "1. Send to single recipient:\n";
            echo "   php email-sender.php single <email> <subject> <template_file>\n\n";
            echo "2. Send to multiple recipients from list:\n";
            echo "   php email-sender.php bulk <recipient_list_file> <template_file> [subject]\n\n";
            echo "3. Send warmup campaign:\n";
            echo "   php email-sender.php warmup\n\n";
            echo "Examples:\n";
            echo "   php email-sender.php single user@example.com 'Hello' letter.html\n";
            echo "   php email-sender.php bulk warmup-list.txt letter.html 'Just checking in'\n";
            echo "   php email-sender.php warmup\n";
            exit(1);
        }

        $command = $argv[1];

        switch ($command) {
            case 'single':
                if ($argc < 5) {
                    echo "Usage: php email-sender.php single <email> <subject> <template_file>\n";
                    exit(1);
                }
                $email = $argv[2];
                $subject = $argv[3];
                $templateFile = $argv[4];

                $template = $sender->loadTemplate($templateFile);
                $variables = [
                    'company_name' => 'FX Avameta',
                    'sender_name' => 'FX Avameta',
                    'sender_email' => 'noreply@fx.avameta.dev',
                    'recipient_email' => $email,
                    'current_year' => date('Y')
                ];
                $htmlBody = $sender->replaceVariables($template, $variables);

                $result = $sender->sendEmail($email, $subject, $htmlBody);
                echo $result['message'] . "\n";
                exit($result['success'] ? 0 : 1);
                break;

            case 'bulk':
                if ($argc < 4) {
                    echo "Usage: php email-sender.php bulk <recipient_list_file> <template_file> [subject]\n";
                    exit(1);
                }
                $listFile = $argv[2];
                $templateFile = $argv[3];
                $subject = $argc >= 5 ? $argv[4] : null;

                $recipients = $sender->loadRecipients($listFile);
                echo "Loaded " . count($recipients) . " recipients\n";

                $template = $sender->loadTemplate($templateFile);
                echo "Template loaded: $templateFile\n";

                echo "Starting bulk send...\n";
                $result = $sender->sendBulkEmails($recipients, $template, $subject);

                echo "\nResults:\n";
                echo "Total: {$result['total']}\n";
                echo "Sent: {$result['sent']}\n";
                echo "Failed: {$result['failed']}\n";
                exit($result['failed'] > 0 ? 1 : 0);
                break;

            case 'warmup':
                echo "Starting warmup campaign...\n";
                $config = json_decode(file_get_contents('/var/email-server/config.json'), true);

                $listFile = '/var/email-server/' . $config['warmup_schedule']['recipient_list_file'];
                $templateFile = '/var/email-server/' . $config['warmup_schedule']['template_file'];

                $recipients = $sender->loadRecipients($listFile);
                echo "Loaded " . count($recipients) . " recipients\n";

                $template = $sender->loadTemplate($templateFile);
                echo "Template loaded\n";

                $result = $sender->sendBulkEmails($recipients, $template);

                echo "\nWarmup Results:\n";
                echo "Total: {$result['total']}\n";
                echo "Sent: {$result['sent']}\n";
                echo "Failed: {$result['failed']}\n";
                exit($result['failed'] > 0 ? 1 : 0);
                break;

            default:
                echo "Unknown command: $command\n";
                echo "Use: single, bulk, or warmup\n";
                exit(1);
        }

    } catch (Exception $e) {
        echo "Error: " . $e->getMessage() . "\n";
        exit(1);
    }
}
