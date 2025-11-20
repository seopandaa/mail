#!/bin/bash

set -e

echo "======================================"
echo "Email Server Installation Script"
echo "Domain: fx.avameta.dev"
echo "======================================"

if [ "$EUID" -ne 0 ]; then
   echo "Please run as root (use sudo)"
   exit 1
fi

echo "[1/8] Updating system packages..."
apt update
apt upgrade -y

echo "[2/8] Installing required packages..."
apt install -y postfix postfix-policyd-spf-python opendkim opendkim-tools mailutils php php-cli composer

echo "[3/8] Creating email directory structure..."
mkdir -p /var/email-server/{config,scripts,keys,logs}
chmod 755 /var/email-server
chown -R root:root /var/email-server

echo "[4/8] Stopping services for configuration..."
systemctl stop postfix opendkim

echo "[5/8] Backing up original configurations..."
cp /etc/postfix/main.cf /etc/postfix/main.cf.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
cp /etc/postfix/master.cf /etc/postfix/master.cf.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true

echo "[6/8] Copying Postfix configurations..."
cp /var/email-server/config/main.cf /etc/postfix/main.cf
cp /var/email-server/config/master.cf /etc/postfix/master.cf

echo "[7/8] Setting up DKIM..."
mkdir -p /etc/opendkim/keys/fx.avameta.dev
cp /var/email-server/config/opendkim.conf /etc/opendkim.conf
cp /var/email-server/config/signing.table /etc/opendkim/signing.table
cp /var/email-server/config/key.table /etc/opendkim/key.table
cp /var/email-server/config/trusted.hosts /etc/opendkim/trusted.hosts

cd /etc/opendkim/keys/fx.avameta.dev
opendkim-genkey -b 2048 -d fx.avameta.dev -D /etc/opendkim/keys/fx.avameta.dev -s mail -v

chown -R opendkim:opendkim /etc/opendkim
chmod -R 700 /etc/opendkim/keys

echo "[8/8] Starting services..."
systemctl enable postfix opendkim
systemctl start opendkim
systemctl start postfix

echo ""
echo "======================================"
echo "Installation Complete!"
echo "======================================"
echo ""
echo "IMPORTANT: Configure your DNS records now!"
echo "Run the following command to get your DKIM public key:"
echo "cat /etc/opendkim/keys/fx.avameta.dev/mail.txt"
echo ""
echo "After DNS configuration, test your setup with:"
echo "php /var/email-server/scripts/test-email.php"
echo ""
