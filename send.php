<?php
/**
 * Simple Email Sender
 *
 * Usage: php send.php
 *
 * Automatically sends emails to all recipients in email-list.txt
 * using the template from letter.html and settings from config.json
 */

require '/var/email-server/scripts/vendor/autoload.php';

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

// File paths
$configFile = '/var/email-server/config.json';
$recipientFile = '/var/email-server/email-list.txt';
$templateFile = '/var/email-server/letter.html';
$logFile = '/var/email-server/logs/email-log.txt';

// Colors for terminal output
function colorText($text, $color = 'green') {
    $colors = [
        'green' => "\033[0;32m",
        'red' => "\033[0;31m",
        'yellow' => "\033[0;33m",
        'blue' => "\033[0;34m",
        'reset' => "\033[0m"
    ];
    return $colors[$color] . $text . $colors['reset'];
}

function logMessage($message, $level = 'INFO') {
    global $logFile;
    $timestamp = date('Y-m-d H:i:s');
    $logMessage = "[$timestamp] [$level] $message\n";

    $logDir = dirname($logFile);
    if (!is_dir($logDir)) {
        mkdir($logDir, 0755, true);
    }

    file_put_contents($logFile, $logMessage, FILE_APPEND);
}

function loadConfig($file) {
    if (!file_exists($file)) {
        throw new Exception("Config file not found: $file");
    }

    $config = json_decode(file_get_contents($file), true);
    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception("Invalid JSON in config file: " . json_last_error_msg());
    }

    return $config;
}

function loadRecipients($file) {
    if (!file_exists($file)) {
        throw new Exception("Recipient list not found: $file");
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

function loadTemplate($file) {
    if (!file_exists($file)) {
        throw new Exception("Template file not found: $file");
    }
    return file_get_contents($file);
}

function replaceVariables($template, $variables) {
    foreach ($variables as $key => $value) {
        $template = str_replace("{{" . strtoupper($key) . "}}", $value, $template);
    }
    return $template;
}

function sendEmail($to, $subject, $htmlBody, $config) {
    $mail = new PHPMailer(true);

    try {
        $mail->isSMTP();
        $mail->Host = 'localhost';
        $mail->SMTPAuth = false;
        $mail->Port = 25;
        $mail->SMTPDebug = 0;

        $senderEmail = $config['email_settings']['sender_email'];
        $senderName = $config['email_settings']['sender_name'];
        $replyToEmail = $config['email_settings']['reply_to_email'];
        $replyToName = $config['email_settings']['reply_to_name'];

        $mail->setFrom($senderEmail, $senderName);
        $mail->addAddress($to);
        $mail->addReplyTo($replyToEmail, $replyToName);

        $mail->isHTML(true);
        $mail->Subject = $subject;
        $mail->Body = $htmlBody;
        $mail->AltBody = strip_tags($htmlBody);

        $mail->send();
        logMessage("Email sent to: $to | Subject: $subject", 'SUCCESS');
        return true;

    } catch (Exception $e) {
        logMessage("Failed to send to: $to | Error: {$mail->ErrorInfo}", 'ERROR');
        return false;
    }
}

function getRandomSubject($config) {
    $subjects = $config['warmup_schedule']['subject_variations'];
    return $subjects[array_rand($subjects)];
}

// Main execution
try {
    echo "\n";
    echo "====================================\n";
    echo "   Simple Email Sender\n";
    echo "====================================\n\n";

    // Load configuration
    echo colorText("→", 'blue') . " Loading configuration...\n";
    $config = loadConfig($configFile);
    echo colorText("  ✓", 'green') . " Config loaded\n\n";

    // Load recipients
    echo colorText("→", 'blue') . " Loading recipients from: email-list.txt\n";
    $recipients = loadRecipients($recipientFile);

    if (empty($recipients)) {
        echo colorText("  ✗", 'red') . " No valid email addresses found\n";
        echo "\nPlease add email addresses to: /var/email-server/email-list.txt\n";
        echo "Format: One email per line\n\n";
        exit(1);
    }

    echo colorText("  ✓", 'green') . " Found " . count($recipients) . " recipients\n\n";

    // Load template
    echo colorText("→", 'blue') . " Loading email template: letter.html\n";
    $template = loadTemplate($templateFile);
    echo colorText("  ✓", 'green') . " Template loaded\n\n";

    // Get settings
    $delay = $config['rate_limiting']['delay_between_emails_seconds'] ?? 5;
    $randomSubject = $config['warmup_schedule']['random_subject'] ?? true;

    echo "====================================\n";
    echo "Settings:\n";
    echo "  • From: {$config['email_settings']['sender_name']} <{$config['email_settings']['sender_email']}>\n";
    echo "  • Recipients: " . count($recipients) . "\n";
    echo "  • Delay: {$delay} seconds between emails\n";
    echo "  • Random subjects: " . ($randomSubject ? 'Yes' : 'No') . "\n";
    echo "====================================\n\n";

    // Confirm before sending
    echo "Ready to send " . count($recipients) . " emails.\n";
    echo "Press ENTER to continue or CTRL+C to cancel...\n";
    if (php_sapi_name() === 'cli') {
        fgets(STDIN);
    }

    echo "\n";
    echo colorText("→", 'blue') . " Starting to send emails...\n\n";

    $sentCount = 0;
    $failedCount = 0;

    foreach ($recipients as $index => $recipient) {
        $num = $index + 1;
        echo "[$num/" . count($recipients) . "] Sending to: $recipient ... ";

        // Prepare variables
        $variables = [
            'company_name' => $config['email_settings']['sender_name'],
            'sender_name' => $config['email_settings']['sender_name'],
            'sender_email' => $config['email_settings']['sender_email'],
            'recipient_email' => $recipient,
            'current_year' => date('Y')
        ];

        $htmlBody = replaceVariables($template, $variables);

        // Get subject
        $subject = $randomSubject ? getRandomSubject($config) : $config['warmup_schedule']['subject_variations'][0];

        // Send email
        $success = sendEmail($recipient, $subject, $htmlBody, $config);

        if ($success) {
            echo colorText("✓ Sent", 'green') . "\n";
            $sentCount++;
        } else {
            echo colorText("✗ Failed", 'red') . "\n";
            $failedCount++;
        }

        // Delay between emails (except for the last one)
        if ($index < count($recipients) - 1) {
            sleep($delay);
        }
    }

    echo "\n";
    echo "====================================\n";
    echo "   Campaign Complete!\n";
    echo "====================================\n";
    echo colorText("Sent:   ", 'green') . $sentCount . "\n";
    if ($failedCount > 0) {
        echo colorText("Failed: ", 'red') . $failedCount . "\n";
    }
    echo "Total:  " . count($recipients) . "\n";
    echo "====================================\n\n";

    echo "Logs saved to: $logFile\n\n";

    logMessage("Campaign completed. Sent: $sentCount, Failed: $failedCount", 'INFO');

    exit($failedCount > 0 ? 1 : 0);

} catch (Exception $e) {
    echo "\n" . colorText("Error: ", 'red') . $e->getMessage() . "\n\n";
    logMessage("Fatal error: " . $e->getMessage(), 'ERROR');
    exit(1);
}
