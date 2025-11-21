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
echo "[4/4] Verifying Postfix is listening on port 25..."

sleep 2  # Give Postfix time to bind to port

if netstat -tuln 2>/dev/null | grep -q ":25 " || ss -tuln 2>/dev/null | grep -q ":25 "; then
    echo "  ✓ Port 25 is listening"
    PORT_OK=1
else
    echo "  ✗ Port 25 is NOT listening"
    echo ""
    echo "Checking Postfix status:"
    systemctl status postfix --no-pager -l
    echo ""
    echo "Checking mail logs:"
    tail -20 /var/log/mail.log 2>/dev/null || journalctl -u postfix -n 20 --no-pager
    PORT_OK=0
fi

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
echo "Network Status:"
echo "Port 25 (SMTP): $(if [ $PORT_OK -eq 1 ]; then echo "Listening ✓"; else echo "Not listening ✗"; fi)"

echo ""
echo "======================================"
if [ $PORT_OK -eq 1 ]; then
    echo "Email Server is Ready!"
    echo "======================================"
    echo ""
    echo "Test with:"
    echo "  php /var/email-server/scripts/test-email.php"
    echo ""
    echo "Or send bulk emails:"
    echo "  cd /var/email-server"
    echo "  php send.php"
else
    echo "Email Server Has Issues!"
    echo "======================================"
    echo ""
    echo "Port 25 is not listening. Fix with:"
    echo "  sudo bash /mail/fix-postfix.sh"
    echo ""
    echo "Check configuration:"
    echo "  postfix check"
    echo ""
    echo "View logs:"
    echo "  tail -f /var/log/mail.log"
fi
echo ""
