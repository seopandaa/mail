#!/bin/bash

echo "======================================"
echo "Updating Email Server Scripts"
echo "======================================"

if [ "$EUID" -ne 0 ]; then
   echo "Please run as root: sudo bash update-scripts.sh"
   exit 1
fi

# Check if source directory exists
if [ ! -d "/mail" ]; then
    echo "Error: /mail directory not found"
    echo "Please ensure the email-server-setup package is extracted to /mail"
    exit 1
fi

echo "[1/4] Backing up existing scripts..."
if [ -d "/var/email-server/scripts" ]; then
    cp -r /var/email-server/scripts /var/email-server/scripts.backup.$(date +%Y%m%d-%H%M%S)
    echo "  ✓ Backup created"
fi

echo "[2/4] Copying updated scripts..."

# Copy the correct warmup-scheduler.php
if [ -f "/mail/warmup-scheduler.php" ]; then
    cp /mail/warmup-scheduler.php /var/email-server/scripts/warmup-scheduler.php
    echo "  ✓ warmup-scheduler.php updated"
else
    echo "  ✗ warmup-scheduler.php not found in /mail"
fi

# Copy the correct email-sender.php
if [ -f "/mail/email-sender.php" ]; then
    cp /mail/email-sender.php /var/email-server/scripts/email-sender.php
    echo "  ✓ email-sender.php updated"
else
    echo "  ✗ email-sender.php not found in /mail"
fi

# Copy test-email.php
if [ -f "/mail/test-email.php" ]; then
    cp /mail/test-email.php /var/email-server/scripts/test-email.php
    echo "  ✓ test-email.php updated"
fi

echo "[3/4] Setting permissions..."
chmod +x /var/email-server/scripts/*.php
chmod 755 /var/email-server/scripts
echo "  ✓ Permissions set"

echo "[4/4] Verifying installation..."

# Check if scripts exist and show their commands
if [ -f "/var/email-server/scripts/warmup-scheduler.php" ]; then
    echo ""
    echo "Warmup Scheduler Commands:"
    php /var/email-server/scripts/warmup-scheduler.php 2>&1 | head -10
fi

echo ""
echo "======================================"
echo "Scripts Updated Successfully!"
echo "======================================"
echo ""
echo "Test the new commands:"
echo "  php /var/email-server/scripts/warmup-scheduler.php status"
echo "  php /var/email-server/scripts/warmup-scheduler.php force"
echo "  php /var/email-server/scripts/warmup-scheduler.php run"
echo ""
