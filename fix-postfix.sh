#!/bin/bash

echo "======================================"
echo "Fixing Postfix Configuration"
echo "======================================"

if [ "$EUID" -ne 0 ]; then
   echo "Please run as root: sudo bash fix-postfix.sh"
   exit 1
fi

echo "[1/5] Copying Postfix configuration files..."

# Copy configuration files from /var/email-server/config/ to /etc/postfix/
if [ -f "/var/email-server/config/main.cf" ]; then
    cp /var/email-server/config/main.cf /etc/postfix/main.cf
    echo "  ✓ main.cf copied"
else
    echo "  ✗ main.cf not found in /var/email-server/config/"
fi

if [ -f "/var/email-server/config/master.cf" ]; then
    cp /var/email-server/config/master.cf /etc/postfix/master.cf
    echo "  ✓ master.cf copied"
else
    echo "  ✗ master.cf not found in /var/email-server/config/"
fi

echo "[2/5] Copying OpenDKIM configuration..."

# Copy OpenDKIM configuration
if [ -f "/var/email-server/config/opendkim.conf" ]; then
    cp /var/email-server/config/opendkim.conf /etc/opendkim.conf
    echo "  ✓ opendkim.conf copied"
fi

# Create OpenDKIM directory if it doesn't exist
mkdir -p /etc/opendkim/keys/fx.avameta.dev

# Copy OpenDKIM keys and tables
for file in signing.table key.table trusted.hosts; do
    if [ -f "/var/email-server/config/$file" ]; then
        cp /var/email-server/config/$file /etc/opendkim/
        echo "  ✓ $file copied"
    fi
done

echo "[3/5] Checking DKIM keys..."

# Check if DKIM keys exist
if [ ! -f "/etc/opendkim/keys/fx.avameta.dev/mail.private" ]; then
    echo "  ⚠ DKIM keys not found. Generating new keys..."
    cd /etc/opendkim/keys/fx.avameta.dev
    opendkim-genkey -b 2048 -d fx.avameta.dev -D /etc/opendkim/keys/fx.avameta.dev -s mail -v
    chown -R opendkim:opendkim /etc/opendkim
    chmod 600 /etc/opendkim/keys/fx.avameta.dev/mail.private
    echo "  ✓ New DKIM keys generated"
    echo ""
    echo "  ⚠ IMPORTANT: You need to add this DKIM record to your DNS:"
    echo ""
    cat /etc/opendkim/keys/fx.avameta.dev/mail.txt
    echo ""
else
    echo "  ✓ DKIM keys already exist"
fi

echo "[4/5] Verifying Postfix configuration..."

# Check Postfix configuration
postfix check

if [ $? -eq 0 ]; then
    echo "  ✓ Postfix configuration is valid"
else
    echo "  ✗ Postfix configuration has errors"
    exit 1
fi

echo "[5/5] Restarting and enabling services..."

# Enable services to start on boot
systemctl enable opendkim >/dev/null 2>&1
systemctl enable postfix >/dev/null 2>&1
echo "  ✓ Services enabled to start on boot"

# Restart services
systemctl restart opendkim
echo "  ✓ OpenDKIM restarted"

systemctl restart postfix
echo "  ✓ Postfix restarted"

echo ""
echo "======================================"
echo "Service Status"
echo "======================================"

systemctl status opendkim --no-pager -l
echo ""
systemctl status postfix --no-pager -l

echo ""
echo "======================================"
echo "Configuration Complete!"
echo "======================================"
echo ""
echo "Test your email server:"
echo "  php /var/email-server/scripts/test-email.php"
echo ""
echo "Check logs if issues persist:"
echo "  tail -f /var/log/mail.log"
echo "  tail -f /var/log/postfix.log"
echo ""
