#!/bin/bash

echo "======================================"
echo "Deploy Simple Email Sender"
echo "======================================"

if [ "$EUID" -ne 0 ]; then
   echo "Please run as root: sudo bash deploy-simple.sh"
   exit 1
fi

echo ""
echo "[1/4] Copying send.php to /var/email-server/..."

if [ ! -d "/var/email-server" ]; then
    echo "  Error: /var/email-server directory not found"
    echo "  Please run setup-server.sh first"
    exit 1
fi

if [ -f "/mail/send.php" ]; then
    cp /mail/send.php /var/email-server/send.php
    chmod +x /var/email-server/send.php
    echo "  ✓ send.php deployed"
else
    echo "  ✗ send.php not found in /mail"
    exit 1
fi

echo ""
echo "[2/4] Creating email-list.txt (if not exists)..."

if [ ! -f "/var/email-server/email-list.txt" ]; then
    cat > /var/email-server/email-list.txt << 'EOF'
# Email List
# Add one email address per line
# Lines starting with # are ignored

# Example (replace with real addresses):
# user1@gmail.com
# user2@yahoo.com
# user3@outlook.com
EOF
    echo "  ✓ email-list.txt created"
    echo "  → Edit: nano /var/email-server/email-list.txt"
else
    echo "  ✓ email-list.txt already exists"
fi

echo ""
echo "[3/4] Checking required files..."

if [ -f "/var/email-server/config.json" ]; then
    echo "  ✓ config.json exists"
else
    echo "  ✗ config.json missing"
fi

if [ -f "/var/email-server/letter.html" ]; then
    echo "  ✓ letter.html exists"
else
    echo "  ✗ letter.html missing"
fi

if [ -d "/var/email-server/scripts/vendor" ]; then
    echo "  ✓ PHPMailer installed"
else
    echo "  ✗ PHPMailer missing - run: cd /var/email-server/scripts && composer install"
fi

echo ""
echo "[4/4] Setting permissions..."
chown -R root:root /var/email-server
chmod 755 /var/email-server
chmod +x /var/email-server/send.php
chmod 644 /var/email-server/email-list.txt
chmod 644 /var/email-server/config.json
chmod 644 /var/email-server/letter.html
echo "  ✓ Permissions set"

echo ""
echo "======================================"
echo "Deployment Complete!"
echo "======================================"
echo ""
echo "Next steps:"
echo ""
echo "1. Add recipients:"
echo "   nano /var/email-server/email-list.txt"
echo ""
echo "2. Edit template:"
echo "   nano /var/email-server/letter.html"
echo ""
echo "3. Configure settings:"
echo "   nano /var/email-server/config.json"
echo ""
echo "4. Send emails:"
echo "   cd /var/email-server"
echo "   php send.php"
echo ""
echo "For detailed instructions:"
echo "   cat /mail/SIMPLE-USAGE.txt"
echo ""
