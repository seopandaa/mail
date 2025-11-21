#!/bin/bash

echo "======================================"
echo "Starting Email Server"
echo "======================================"

if [ "$EUID" -ne 0 ]; then
   echo "Please run as root: sudo bash start-email-server.sh"
   exit 1
fi

echo ""
echo "[1/3] Checking Postfix status..."

if systemctl is-active --quiet postfix; then
    echo "  ✓ Postfix is already running"
else
    echo "  ⚠ Postfix is not running. Starting..."
    systemctl start postfix

    if systemctl is-active --quiet postfix; then
        echo "  ✓ Postfix started successfully"
    else
        echo "  ✗ Failed to start Postfix"
        echo ""
        echo "Checking logs:"
        journalctl -u postfix -n 20 --no-pager
        exit 1
    fi
fi

echo ""
echo "[2/3] Checking OpenDKIM status..."

if systemctl is-active --quiet opendkim; then
    echo "  ✓ OpenDKIM is already running"
else
    echo "  ⚠ OpenDKIM is not running. Starting..."
    systemctl start opendkim

    if systemctl is-active --quiet opendkim; then
        echo "  ✓ OpenDKIM started successfully"
    else
        echo "  ✗ Failed to start OpenDKIM"
        echo ""
        echo "Checking logs:"
        journalctl -u opendkim -n 20 --no-pager
        exit 1
    fi
fi

echo ""
echo "[3/3] Enabling services to start on boot..."

systemctl enable postfix >/dev/null 2>&1
systemctl enable opendkim >/dev/null 2>&1
echo "  ✓ Services enabled"

echo ""
echo "======================================"
echo "Service Status"
echo "======================================"
echo ""

echo "Postfix:"
systemctl status postfix --no-pager | head -3
echo ""

echo "OpenDKIM:"
systemctl status opendkim --no-pager | head -3

echo ""
echo "======================================"
echo "Email Server is Ready!"
echo "======================================"
echo ""
echo "Test with:"
echo "  php /var/email-server/scripts/test-email.php"
echo ""
echo "Or send bulk emails:"
echo "  cd /var/email-server"
echo "  php send.php"
echo ""
