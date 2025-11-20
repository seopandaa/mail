<?php

require '/var/email-server/scripts/vendor/autoload.php';

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\SMTP;
use PHPMailer\PHPMailer\Exception;

$mail = new PHPMailer(true);

try {
    $mail->SMTPDebug = SMTP::DEBUG_SERVER;
    $mail->isSMTP();
    $mail->Host       = 'localhost';
    $mail->SMTPAuth   = false;
    $mail->Port       = 25;

    $mail->setFrom('noreply@fx.avameta.dev', 'FX Avameta Mailer');
    $mail->addAddress('test@example.com', 'Test Recipient');
    $mail->addReplyTo('support@fx.avameta.dev', 'Support Team');

    $mail->isHTML(true);
    $mail->Subject = 'Test Email from fx.avameta.dev - ' . date('Y-m-d H:i:s');
    $mail->Body    = '<html><body>';
    $mail->Body   .= '<h1>Email Server Test</h1>';
    $mail->Body   .= '<p>This is a test email from your fx.avameta.dev email server.</p>';
    $mail->Body   .= '<p><strong>Server:</strong> fx.avameta.dev</p>';
    $mail->Body   .= '<p><strong>Time:</strong> ' . date('Y-m-d H:i:s') . '</p>';
    $mail->Body   .= '<p>If you receive this email, your email server is working correctly!</p>';
    $mail->Body   .= '</body></html>';
    $mail->AltBody = 'This is a test email from your fx.avameta.dev email server. Time: ' . date('Y-m-d H:i:s');

    $mail->send();
    echo "\n✓ Email sent successfully!\n";
    echo "Check the recipient inbox: test@example.com\n";

} catch (Exception $e) {
    echo "\n✗ Email could not be sent.\n";
    echo "Error: {$mail->ErrorInfo}\n";
}
