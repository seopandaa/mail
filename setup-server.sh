#!/bin/bash

set -e

echo "======================================"
echo "Email Server Complete Setup"
echo "======================================"

if [ "$EUID" -ne 0 ]; then
   echo "Please run as root: sudo bash setup-server.sh"
   exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "[Step 1] Creating directory structure..."
mkdir -p /var/email-server/{config,scripts,keys,logs}

echo "[Step 2] Copying configuration files..."
cp "$SCRIPT_DIR/main.cf" /var/email-server/config/
cp "$SCRIPT_DIR/master.cf" /var/email-server/config/
cp "$SCRIPT_DIR/opendkim.conf" /var/email-server/config/
cp "$SCRIPT_DIR/signing.table" /var/email-server/config/
cp "$SCRIPT_DIR/key.table" /var/email-server/config/
cp "$SCRIPT_DIR/trusted.hosts" /var/email-server/config/

echo "[Step 3] Copying PHP scripts..."
cp "$SCRIPT_DIR/test-email.php" /var/email-server/scripts/
cp "$SCRIPT_DIR/send-email.php" /var/email-server/scripts/
cp "$SCRIPT_DIR/composer.json" /var/email-server/scripts/

echo "[Step 4] Setting up mailname..."
echo "fx.avameta.dev" > /etc/mailname

echo "[Step 5] Running installation script..."
cp "$SCRIPT_DIR/install.sh" /var/email-server/install.sh
chmod +x /var/email-server/install.sh
bash /var/email-server/install.sh

echo "[Step 6] Installing PHPMailer..."
cd /var/email-server/scripts
composer install --no-dev --optimize-autoloader

echo "[Step 7] Setting permissions..."
chmod +x /var/email-server/scripts/*.php
chmod 755 /var/email-server/scripts
chmod 644 /var/email-server/config/*

echo ""
echo "======================================"
echo "Setup Complete!"
echo "======================================"
echo ""
echo "Next Steps:"
echo ""
echo "1. Get your DKIM key:"
echo "   sudo cat /etc/opendkim/keys/fx.avameta.dev/mail.txt"
echo ""
echo "2. Configure DNS records (see DNS-RECORDS.txt)"
echo ""
echo "3. Test your email server:"
echo "   sudo php /var/email-server/scripts/test-email.php"
echo ""
echo "4. Send custom emails:"
echo "   sudo php /var/email-server/scripts/send-email.php recipient@example.com 'Name' 'Subject' '<html>Body</html>'"
echo ""
