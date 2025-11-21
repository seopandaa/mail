#!/bin/bash

echo "======================================"
echo "Installing Cron & Setting Up Schedule"
echo "======================================"

if [ "$EUID" -ne 0 ]; then
   echo "Please run as root: sudo bash fix-cron.sh"
   exit 1
fi

# Install cron
echo "[1/3] Installing cron..."
apt-get update -qq
apt-get install -y cron

# Enable and start cron service
echo "[2/3] Starting cron service..."
systemctl enable cron
systemctl start cron

# Add cron job
echo "[3/3] Adding warmup scheduler cron job..."
CRON_JOB="*/5 * * * * /usr/bin/php /var/email-server/scripts/warmup-scheduler.php run >> /var/email-server/logs/cron.log 2>&1"
(crontab -l 2>/dev/null | grep -v "warmup-scheduler.php"; echo "$CRON_JOB") | crontab -

echo ""
echo "======================================"
echo "Cron Setup Complete!"
echo "======================================"
echo ""
echo "Cron job installed:"
crontab -l
echo ""
echo "The warmup scheduler will run every 5 minutes."
echo ""
echo "Test your setup:"
echo "  php /var/email-server/scripts/warmup-scheduler.php status"
echo ""
