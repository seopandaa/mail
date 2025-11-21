#!/bin/bash

echo "======================================"
echo "Email Server Diagnostics"
echo "======================================"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo "Running comprehensive diagnostics..."
echo ""

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    IS_ROOT=1
else
    IS_ROOT=0
fi

echo "======================================"
echo "1. System Information"
echo "======================================"
echo ""
echo "Hostname: $(hostname)"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "Kernel: $(uname -r)"
echo "Date: $(date)"
echo "Timezone: $(timedatectl | grep "Time zone" | awk '{print $3}')"
echo ""

echo "======================================"
echo "2. Service Status"
echo "======================================"
echo ""

# Check Postfix
if systemctl is-active --quiet postfix; then
    print_status 0 "Postfix is running"
    POSTFIX_RUNNING=1
else
    print_status 1 "Postfix is NOT running"
    POSTFIX_RUNNING=0
fi

if systemctl is-enabled --quiet postfix 2>/dev/null; then
    print_status 0 "Postfix is enabled (auto-start)"
else
    print_status 1 "Postfix is NOT enabled (won't auto-start)"
fi

# Check OpenDKIM
if systemctl is-active --quiet opendkim; then
    print_status 0 "OpenDKIM is running"
    OPENDKIM_RUNNING=1
else
    print_status 1 "OpenDKIM is NOT running"
    OPENDKIM_RUNNING=0
fi

if systemctl is-enabled --quiet opendkim 2>/dev/null; then
    print_status 0 "OpenDKIM is enabled (auto-start)"
else
    print_status 1 "OpenDKIM is NOT enabled (won't auto-start)"
fi

echo ""

echo "======================================"
echo "3. Configuration Files"
echo "======================================"
echo ""

# Check Postfix config
if [ -f "/etc/postfix/main.cf" ]; then
    print_status 0 "Postfix main.cf exists"
else
    print_status 1 "Postfix main.cf MISSING"
fi

if [ -f "/etc/postfix/master.cf" ]; then
    print_status 0 "Postfix master.cf exists"
else
    print_status 1 "Postfix master.cf MISSING"
fi

# Check OpenDKIM config
if [ -f "/etc/opendkim.conf" ]; then
    print_status 0 "OpenDKIM config exists"
else
    print_status 1 "OpenDKIM config MISSING"
fi

# Check DKIM keys
if [ -f "/etc/opendkim/keys/fx.avameta.dev/mail.private" ]; then
    print_status 0 "DKIM private key exists"
else
    print_status 1 "DKIM private key MISSING"
fi

# Check email-server directory
if [ -d "/var/email-server" ]; then
    print_status 0 "/var/email-server directory exists"
else
    print_status 1 "/var/email-server directory MISSING"
fi

if [ -f "/var/email-server/config.json" ]; then
    print_status 0 "config.json exists"
else
    print_status 1 "config.json MISSING"
fi

if [ -f "/var/email-server/send.php" ]; then
    print_status 0 "send.php exists"
else
    print_status 1 "send.php MISSING"
fi

if [ -f "/var/email-server/email-list.txt" ]; then
    print_status 0 "email-list.txt exists"
else
    print_status 1 "email-list.txt MISSING"
fi

if [ -f "/var/email-server/letter.html" ]; then
    print_status 0 "letter.html exists"
else
    print_status 1 "letter.html MISSING"
fi

echo ""

echo "======================================"
echo "4. Network & Ports"
echo "======================================"
echo ""

# Check if port 25 is listening
if netstat -tuln 2>/dev/null | grep -q ":25 "; then
    print_status 0 "Port 25 (SMTP) is listening"
else
    print_status 1 "Port 25 (SMTP) is NOT listening"
fi

echo ""

echo "======================================"
echo "5. Recent Logs"
echo "======================================"
echo ""

echo "Last 10 Postfix log entries:"
if [ -f "/var/log/mail.log" ]; then
    tail -10 /var/log/mail.log 2>/dev/null | sed 's/^/  /'
else
    echo "  No mail.log found"
fi

echo ""
echo "Last 5 email-log entries:"
if [ -f "/var/email-server/logs/email-log.txt" ]; then
    tail -5 /var/email-server/logs/email-log.txt 2>/dev/null | sed 's/^/  /'
else
    echo "  No email-log.txt found"
fi

echo ""

echo "======================================"
echo "6. Recommendations"
echo "======================================"
echo ""

if [ $POSTFIX_RUNNING -eq 0 ] || [ $OPENDKIM_RUNNING -eq 0 ]; then
    echo -e "${YELLOW}⚠${NC} Services are not running"
    echo ""
    echo "Fix with:"
    echo "  sudo bash /mail/fix-postfix.sh"
    echo ""
    echo "Or start manually:"
    echo "  sudo bash /mail/start-email-server.sh"
    echo ""
fi

if systemctl is-enabled --quiet postfix 2>/dev/null; then
    :
else
    echo -e "${YELLOW}⚠${NC} Postfix is not enabled for auto-start"
    echo ""
    echo "Enable with:"
    echo "  sudo systemctl enable postfix"
    echo ""
fi

if [ ! -f "/var/email-server/send.php" ]; then
    echo -e "${YELLOW}⚠${NC} send.php is missing"
    echo ""
    echo "Deploy with:"
    echo "  sudo bash /mail/deploy-simple.sh"
    echo ""
fi

if [ $POSTFIX_RUNNING -eq 1 ] && [ $OPENDKIM_RUNNING -eq 1 ]; then
    echo -e "${GREEN}✓${NC} All services are running"
    echo ""
    echo "Test with:"
    echo "  cd /var/email-server"
    echo "  php send.php"
    echo ""
fi

echo "======================================"
echo "Quick Actions"
echo "======================================"
echo ""
echo "Check service status:"
echo "  sudo bash /mail/check-email-server.sh"
echo ""
echo "Start services:"
echo "  sudo bash /mail/start-email-server.sh"
echo ""
echo "Fix configuration:"
echo "  sudo bash /mail/fix-postfix.sh"
echo ""
echo "View live logs:"
echo "  tail -f /var/log/mail.log"
echo "  tail -f /var/email-server/logs/email-log.txt"
echo ""
