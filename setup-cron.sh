#!/bin/bash

echo "======================================"
echo "Email Warmup Cron Setup"
echo "======================================"

if [ "$EUID" -ne 0 ]; then
   echo "Please run as root: sudo bash setup-cron.sh"
   exit 1
fi

echo "[1/3] Copying new scripts to /var/email-server/scripts/..."
cp email-sender.php /var/email-server/scripts/
cp warmup-scheduler.php /var/email-server/scripts/
chmod +x /var/email-server/scripts/email-sender.php
chmod +x /var/email-server/scripts/warmup-scheduler.php

echo "[2/3] Copying configuration files to /var/email-server/..."
cp config.json /var/email-server/
cp letter.html /var/email-server/
cp warmup-list.txt /var/email-server/

echo "[3/3] Setting up cron job..."

CRON_JOB="*/5 * * * * /usr/bin/php /var/email-server/scripts/warmup-scheduler.php run >> /var/email-server/logs/cron.log 2>&1"

(crontab -l 2>/dev/null | grep -v "warmup-scheduler.php"; echo "$CRON_JOB") | crontab -

echo ""
echo "======================================"
echo "Cron Setup Complete!"
echo "======================================"
echo ""
echo "The warmup scheduler will run every 5 minutes and check if it's time to send."
echo ""
echo "Configuration file: /var/email-server/config.json"
echo "Email template: /var/email-server/letter.html"
echo "Recipient list: /var/email-server/warmup-list.txt"
echo ""
echo "Next steps:"
echo "1. Edit config.json to customize sender details and schedule"
echo "2. Edit warmup-list.txt to add recipient email addresses"
echo "3. Customize letter.html email template if needed"
echo ""
echo "Useful commands:"
echo "  - Check scheduler status:"
echo "    php /var/email-server/scripts/warmup-scheduler.php status"
echo ""
echo "  - Force run warmup campaign:"
echo "    php /var/email-server/scripts/warmup-scheduler.php force"
echo ""
echo "  - Send to custom list:"
echo "    php /var/email-server/scripts/email-sender.php bulk <list.txt> <template.html> 'Subject'"
echo ""
echo "  - View logs:"
echo "    tail -f /var/email-server/logs/warmup-scheduler.log"
echo "    tail -f /var/email-server/logs/email-log.txt"
echo ""
echo "  - View cron log:"
echo "    tail -f /var/email-server/logs/cron.log"
echo ""
