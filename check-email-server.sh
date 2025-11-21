#!/bin/bash

echo "======================================"
echo "Email Server Health Check"
echo "======================================"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo ""
echo "Checking services..."
echo ""

# Check Postfix
echo -n "Postfix:   "
if systemctl is-active --quiet postfix; then
    echo -e "${GREEN}✓ Running${NC}"
    POSTFIX_STATUS=0
else
    echo -e "${RED}✗ Stopped${NC}"
    POSTFIX_STATUS=1
fi

# Check OpenDKIM
echo -n "OpenDKIM:  "
if systemctl is-active --quiet opendkim; then
    echo -e "${GREEN}✓ Running${NC}"
    OPENDKIM_STATUS=0
else
    echo -e "${RED}✗ Stopped${NC}"
    OPENDKIM_STATUS=1
fi

echo ""
echo "Checking configuration files..."
echo ""

# Check config files
CONFIG_OK=1

FILES=(
    "/etc/postfix/main.cf:Postfix main config"
    "/etc/postfix/master.cf:Postfix master config"
    "/etc/opendkim.conf:OpenDKIM config"
    "/etc/opendkim/keys/fx.avameta.dev/mail.private:DKIM private key"
    "/var/email-server/config.json:Email config"
    "/var/email-server/letter.html:Email template"
)

for item in "${FILES[@]}" ; do
    FILE="${item%%:*}"
    DESC="${item##*:}"
    echo -n "$DESC: "
    if [ -f "$FILE" ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ Missing${NC}"
        CONFIG_OK=0
    fi
done

echo ""
echo "Checking directories..."
echo ""

DIRS=(
    "/var/email-server:Main directory"
    "/var/email-server/scripts:Scripts directory"
    "/var/email-server/logs:Logs directory"
)

for item in "${DIRS[@]}" ; do
    DIR="${item%%:*}"
    DESC="${item##*:}"
    echo -n "$DESC: "
    if [ -d "$DIR" ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ Missing${NC}"
        CONFIG_OK=0
    fi
done

echo ""
echo "======================================"
echo "Summary"
echo "======================================"
echo ""

if [ $POSTFIX_STATUS -eq 0 ] && [ $OPENDKIM_STATUS -eq 0 ] && [ $CONFIG_OK -eq 1 ]; then
    echo -e "${GREEN}✓ Email server is healthy${NC}"
    echo ""
    echo "Ready to send emails:"
    echo "  cd /var/email-server"
    echo "  php send.php"
    exit 0
else
    echo -e "${RED}✗ Email server has issues${NC}"
    echo ""

    if [ $POSTFIX_STATUS -ne 0 ] || [ $OPENDKIM_STATUS -ne 0 ]; then
        echo "Fix services with:"
        echo "  sudo bash /mail/fix-postfix.sh"
        echo ""
        echo "Or start services manually:"
        echo "  sudo bash /mail/start-email-server.sh"
    fi

    if [ $CONFIG_OK -ne 1 ]; then
        echo "Missing configuration files."
        echo "Run initial setup:"
        echo "  sudo bash /mail/setup-server.sh"
    fi

    exit 1
fi
