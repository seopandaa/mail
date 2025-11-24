<?php
/**
 * Multi-Domain Email Sender
 *
 * Usage:
 *   php send-multi.php                    (select domain interactively)
 *   php send-multi.php --domain example.com
 *   php send-multi.php -d example.com
 *
 * Sends emails using selected domain configuration
 */

require '/var/email-server/scripts/vendor/autoload.php';

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

// File paths
$configFile = '/var/email-server/config.json';
$recipientFile = '/var/email-server/email-list.txt';
$templateFile = '/var/email-server/letter.html';
$logFile = '/var/email-server/logs/email-log.txt';

// Parse command line arguments
$selectedDomain = null;
$args = array_slice($argv, 1);
for ($i = 0; $i < count($args); $i++) {
    if (($args[$i] === '--domain' || $args[$i] === '-d') && isset($args[$i + 1])) {
        $selectedDomain = $args[$i + 1];
        break;
    }
}

// Colors for terminal output
function colorText($text, $color = 'green') {
    $colors = [
        'green' => "\033[0;32m",
        'red' => "\033[0;31m",
        'yellow' => "\033[0;33m",
        'blue' => "\033[0;34m",
        'cyan' => "\033[0;36m",
        'reset' => "\033[0m"
    ];
    return $colors[$color] . $text . $colors['reset'];
}

function checkPostfixRunning() {
    exec('systemctl is-active postfix 2>&1', $output, $return);
    return $return === 0;
}

function startPostfix() {
    echo colorText("⚠", 'yellow') . " Postfix is not running. Starting...\n";
    exec('sudo systemctl start postfix 2>&1', $output, $return);

    if ($return === 0) {
        sleep(2);
        if (checkPostfixRunning()) {
            echo colorText("  ✓", 'green') . " Postfix started successfully\n\n";
            return true;
        }
    }

    return false;
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

function getAvailableDomains($config) {
    if (isset($config['domains'])) {
        return array_filter($config['domains'], function($domain) {
            return isset($domain['enabled']) && $domain['enabled'] === true;
        });
    }

    // Legacy config format - single domain
    return [[
        'domain' => extractDomain($config['email_settings']['sender_email']),
        'name' => $config['email_settings']['sender_name'],
        'sender_email' => $config['email_settings']['sender_email'],
        'sender_name' => $config['email_settings']['sender_name'],
        'reply_to_email' => $config['email_settings']['reply_to_email'],
        'reply_to_name' => $config['email_settings']['reply_to_name'],
        'enabled' => true,
        'is_default' => true
    ]];
}

function extractDomain($email) {
    $parts = explode('@', $email);
    return isset($parts[1]) ? $parts[1] : '';
}

function selectDomain($domains, $selectedDomain = null) {
    if ($selectedDomain) {
        foreach ($domains as $domain) {
            if ($domain['domain'] === $selectedDomain) {
                return $domain;
            }
        }
        throw new Exception("Domain not found: $selectedDomain");
    }

    // Interactive selection
    if (count($domains) === 1) {
        return $domains[0];
    }

    echo "\n";
    echo colorText("Available Domains:", 'cyan') . "\n";
    echo str_repeat("=", 50) . "\n";

    foreach ($domains as $index => $domain) {
        $num = $index + 1;
        $default = isset($domain['is_default']) && $domain['is_default'] ? colorText(" [DEFAULT]", 'green') : '';
        echo colorText("[$num]", 'yellow') . " {$domain['domain']} - {$domain['name']}$default\n";
        echo "    From: {$domain['sender_email']}\n";
    }

    echo str_repeat("=", 50) . "\n";
    echo "\nSelect domain number (1-" . count($domains) . "): ";

    $handle = fopen("php://stdin", "r");
    $line = fgets($handle);
    $selection = (int)trim($line);
    fclose($handle);

    if ($selection < 1 || $selection > count($domains)) {
        throw new Exception("Invalid selection");
    }

    return $domains[$selection - 1];
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

function sendEmail($to, $subject, $htmlBody, $domainConfig) {
    $mail = new PHPMailer(true);

    try {
        $mail->isSMTP();
        $mail->Host = 'localhost';
        $mail->SMTPAuth = false;
        $mail->Port = 25;
        $mail->SMTPDebug = 0;

        $senderEmail = $domainConfig['sender_email'];
        $senderName = $domainConfig['sender_name'];
        $replyToEmail = $domainConfig['reply_to_email'];
        $replyToName = $domainConfig['reply_to_name'];

        $mail->setFrom($senderEmail, $senderName);
        $mail->addAddress($to);
        $mail->addReplyTo($replyToEmail, $replyToName);

        $mail->isHTML(true);
        $mail->Subject = $subject;
        $mail->Body = $htmlBody;
        $mail->AltBody = strip_tags($htmlBody);

        $mail->send();
        logMessage("Email sent to: $to | From: $senderEmail | Subject: $subject", 'SUCCESS');
        return true;

    } catch (Exception $e) {
        logMessage("Failed to send to: $to | From: $senderEmail | Error: {$mail->ErrorInfo}", 'ERROR');
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
    echo "   Multi-Domain Email Sender\n";
    echo "====================================\n\n";

    // Check Postfix status
    echo colorText("→", 'blue') . " Checking email server...\n";
    if (!checkPostfixRunning()) {
        if (!startPostfix()) {
            echo colorText("  ✗", 'red') . " Failed to start Postfix\n\n";
            echo "Please run manually:\n";
            echo "  sudo systemctl start postfix\n\n";
            echo "Or fix configuration:\n";
            echo "  sudo bash /mail/fix-postfix.sh\n\n";
            exit(1);
        }
    } else {
        echo colorText("  ✓", 'green') . " Postfix is running\n\n";
    }

    // Load configuration
    echo colorText("→", 'blue') . " Loading configuration...\n";
    $config = loadConfig($configFile);
    echo colorText("  ✓", 'green') . " Config loaded\n";

    // Get available domains
    $domains = getAvailableDomains($config);
    echo colorText("  ✓", 'green') . " Found " . count($domains) . " domain(s)\n\n";

    // Select domain
    $domainConfig = selectDomain($domains, $selectedDomain);

    echo "\n";
    echo colorText("Selected Domain:", 'cyan') . "\n";
    echo "  Domain: {$domainConfig['domain']}\n";
    echo "  Name: {$domainConfig['name']}\n";
    echo "  From: {$domainConfig['sender_email']}\n";
    echo "  Reply-To: {$domainConfig['reply_to_email']}\n";
    echo "\n";

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
    echo "Campaign Settings:\n";
    echo "  • Domain: {$domainConfig['domain']}\n";
    echo "  • From: {$domainConfig['sender_name']} <{$domainConfig['sender_email']}>\n";
    echo "  • Recipients: " . count($recipients) . "\n";
    echo "  • Delay: {$delay} seconds between emails\n";
    echo "  • Random subjects: " . ($randomSubject ? 'Yes' : 'No') . "\n";
    echo "====================================\n\n";

    // Confirm before sending
    echo "Ready to send " . count($recipients) . " emails from {$domainConfig['domain']}.\n";
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
            'company_name' => $domainConfig['name'],
            'sender_name' => $domainConfig['sender_name'],
            'sender_email' => $domainConfig['sender_email'],
            'recipient_email' => $recipient,
            'current_year' => date('Y'),
            'domain' => $domainConfig['domain']
        ];

        $htmlBody = replaceVariables($template, $variables);

        // Get subject
        $subject = $randomSubject ? getRandomSubject($config) : $config['warmup_schedule']['subject_variations'][0];

        // Send email
        $success = sendEmail($recipient, $subject, $htmlBody, $domainConfig);

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
    echo "Domain: {$domainConfig['domain']}\n";
    echo colorText("Sent:   ", 'green') . $sentCount . "\n";
    if ($failedCount > 0) {
        echo colorText("Failed: ", 'red') . $failedCount . "\n";
    }
    echo "Total:  " . count($recipients) . "\n";
    echo "====================================\n\n";

    echo "Logs saved to: $logFile\n\n";

    logMessage("Campaign completed for domain {$domainConfig['domain']}. Sent: $sentCount, Failed: $failedCount", 'INFO');

    exit($failedCount > 0 ? 1 : 0);

} catch (Exception $e) {
    echo "\n" . colorText("Error: ", 'red') . $e->getMessage() . "\n\n";
    logMessage("Fatal error: " . $e->getMessage(), 'ERROR');
    exit(1);
}
