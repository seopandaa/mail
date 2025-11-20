<?php

require '/var/email-server/scripts/vendor/autoload.php';

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\SMTP;
use PHPMailer\PHPMailer\Exception;

function sendEmail($to, $toName, $subject, $htmlBody, $altBody = '') {
    $mail = new PHPMailer(true);

    try {
        $mail->isSMTP();
        $mail->Host       = 'localhost';
        $mail->SMTPAuth   = false;
        $mail->Port       = 25;
        $mail->SMTPDebug  = 0;

        $mail->setFrom('noreply@fx.avameta.dev', 'FX Avameta');
        $mail->addAddress($to, $toName);
        $mail->addReplyTo('support@fx.avameta.dev', 'Support');

        $mail->isHTML(true);
        $mail->Subject = $subject;
        $mail->Body    = $htmlBody;
        $mail->AltBody = $altBody ?: strip_tags($htmlBody);

        $mail->send();
        return ['success' => true, 'message' => 'Email sent successfully'];

    } catch (Exception $e) {
        return ['success' => false, 'message' => $mail->ErrorInfo];
    }
}

if (php_sapi_name() === 'cli') {
    if ($argc < 4) {
        echo "Usage: php send-email.php <recipient_email> <recipient_name> <subject> <html_body>\n";
        echo "Example: php send-email.php user@example.com 'John Doe' 'Hello' '<h1>Welcome</h1>'\n";
        exit(1);
    }

    $result = sendEmail($argv[1], $argv[2], $argv[3], $argv[4]);
    echo $result['message'] . "\n";
    exit($result['success'] ? 0 : 1);
}
