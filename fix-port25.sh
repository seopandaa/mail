#!/bin/bash

echo "======================================"
echo "Fix Port 25 Not Listening Issue"
echo "======================================"

if [ "$EUID" -ne 0 ]; then
   echo "Please run as root: sudo bash fix-port25.sh"
   exit 1
fi

echo ""
echo "Diagnosing port 25 issue..."
echo ""

# Check if Postfix is running
echo "[1/6] Checking if Postfix is running..."
if systemctl is-active --quiet postfix; then
    echo "  ✓ Postfix service is active"
else
    echo "  ✗ Postfix service is NOT active"
    echo "  → Starting Postfix..."
    systemctl start postfix
    sleep 2
fi

# Check if port 25 is listening
echo ""
echo "[2/6] Checking if port 25 is listening..."
if netstat -tuln 2>/dev/null | grep -q ":25 " || ss -tuln 2>/dev/null | grep -q ":25 "; then
    echo "  ✓ Port 25 is listening - All good!"
    echo ""
    echo "Your email server is working correctly."
    exit 0
else
    echo "  ✗ Port 25 is NOT listening"
fi

# Check Postfix configuration
echo ""
echo "[3/6] Checking Postfix configuration..."
if postfix check 2>&1 | grep -q "error"; then
    echo "  ✗ Postfix configuration has errors:"
    postfix check
    echo ""
    echo "Fix configuration first, then run this script again."
    exit 1
else
    echo "  ✓ Postfix configuration is valid"
fi

# Check if another process is using port 25
echo ""
echo "[4/6] Checking if another process is using port 25..."
OTHER_PROCESS=$(lsof -i :25 2>/dev/null | grep -v "COMMAND" | head -1)
if [ -n "$OTHER_PROCESS" ]; then
    echo "  ⚠ Another process is using port 25:"
    echo "  $OTHER_PROCESS"
    echo ""
    echo "You may need to stop other mail services:"
    echo "  systemctl stop sendmail exim4 2>/dev/null"
else
    echo "  ✓ No conflicting processes found"
fi

# Check Postfix master process
echo ""
echo "[5/6] Checking Postfix processes..."
POSTFIX_PROCS=$(ps aux | grep -v grep | grep postfix | wc -l)
if [ $POSTFIX_PROCS -gt 0 ]; then
    echo "  ✓ Postfix has $POSTFIX_PROCS running processes"
else
    echo "  ✗ No Postfix processes found"
    echo "  → This is the problem!"
fi

# Check recent logs
echo ""
echo "[6/6] Checking recent error logs..."
if [ -f /var/log/mail.log ]; then
    ERRORS=$(tail -50 /var/log/mail.log | grep -i "error\|fatal\|panic" | tail -5)
    if [ -n "$ERRORS" ]; then
        echo "  Recent errors found:"
        echo "$ERRORS" | sed 's/^/    /'
    else
        echo "  ✓ No recent errors in logs"
    fi
else
    echo "  ⚠ No mail.log found"
fi

echo ""
echo "======================================"
echo "Attempting Fixes"
echo "======================================"
echo ""

# Stop Postfix
echo "[Fix 1/4] Stopping Postfix completely..."
systemctl stop postfix
sleep 2
echo "  ✓ Stopped"

# Stop conflicting services
echo ""
echo "[Fix 2/4] Stopping potentially conflicting services..."
systemctl stop sendmail 2>/dev/null && echo "  ✓ Stopped sendmail" || echo "  - sendmail not running"
systemctl stop exim4 2>/dev/null && echo "  ✓ Stopped exim4" || echo "  - exim4 not running"

# Verify configuration files exist
echo ""
echo "[Fix 3/4] Verifying configuration files..."
if [ -f "/etc/postfix/main.cf" ]; then
    echo "  ✓ main.cf exists"
else
    echo "  ✗ main.cf missing - copying from backup"
    if [ -f "/var/email-server/config/main.cf" ]; then
        cp /var/email-server/config/main.cf /etc/postfix/main.cf
        echo "  ✓ Copied from /var/email-server/config/"
    elif [ -f "/mail/main.cf" ]; then
        cp /mail/main.cf /etc/postfix/main.cf
        echo "  ✓ Copied from /mail/"
    fi
fi

if [ -f "/etc/postfix/master.cf" ]; then
    echo "  ✓ master.cf exists"
else
    echo "  ✗ master.cf missing - copying from backup"
    if [ -f "/var/email-server/config/master.cf" ]; then
        cp /var/email-server/config/master.cf /etc/postfix/master.cf
        echo "  ✓ Copied from /var/email-server/config/"
    elif [ -f "/mail/master.cf" ]; then
        cp /mail/master.cf /etc/postfix/master.cf
        echo "  ✓ Copied from /mail/"
    fi
fi

# Start Postfix
echo ""
echo "[Fix 4/4] Starting Postfix..."
systemctl start postfix
sleep 3
echo "  ✓ Started"

# Final verification
echo ""
echo "======================================"
echo "Final Verification"
echo "======================================"
echo ""

echo "Postfix status:"
if systemctl is-active --quiet postfix; then
    echo "  ✓ Running"
else
    echo "  ✗ Not running"
    echo ""
    echo "Check errors:"
    journalctl -u postfix -n 20 --no-pager
    exit 1
fi

echo ""
echo "Port 25 status:"
if netstat -tuln 2>/dev/null | grep -q ":25 " || ss -tuln 2>/dev/null | grep -q ":25 "; then
    echo "  ✓ Listening - FIXED!"
    echo ""
    echo "======================================"
    echo "Success! Email server is working!"
    echo "======================================"
    echo ""
    echo "Test with:"
    echo "  cd /var/email-server"
    echo "  php send.php"
    echo ""
    exit 0
else
    echo "  ✗ NOT listening - Still having issues"
    echo ""
    echo "======================================"
    echo "Manual Troubleshooting Required"
    echo "======================================"
    echo ""
    echo "1. Check Postfix status:"
    echo "   systemctl status postfix -l"
    echo ""
    echo "2. Check logs:"
    echo "   journalctl -u postfix -n 50"
    echo "   tail -50 /var/log/mail.log"
    echo ""
    echo "3. Verify configuration:"
    echo "   postfix check"
    echo ""
    echo "4. Check what's listening on ports:"
    echo "   netstat -tuln | grep LISTEN"
    echo "   ss -tuln"
    echo ""
    echo "5. Check for port conflicts:"
    echo "   lsof -i :25"
    echo ""
    exit 1
fi
