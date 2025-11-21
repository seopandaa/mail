#!/bin/bash

set -e

echo "======================================"
echo "Centralizing Email Server Files"
echo "Migration to /var/email-server"
echo "======================================"

if [ "$EUID" -ne 0 ]; then
   echo "Please run as root: sudo bash migrate-to-var.sh"
   exit 1
fi

# Get the current directory where script is run from
CURRENT_DIR="$(pwd)"

echo ""
echo "Current directory: $CURRENT_DIR"
echo "Target directory: /var/email-server"
echo ""

# Create backup
echo "[1/8] Creating backup..."
BACKUP_DIR="/root/email-server-backup-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
if [ -d "/var/email-server" ]; then
    cp -r /var/email-server "$BACKUP_DIR/"
    echo "Backup created at: $BACKUP_DIR"
fi

# Ensure /var/email-server directory structure exists
echo "[2/8] Creating directory structure..."
mkdir -p /var/email-server/{config,scripts,keys,logs}
mkdir -p /var/email-server/scripts/vendor

# Copy configuration files if they don't exist in /var/email-server
echo "[3/8] Copying configuration files..."

# Main configuration files
if [ -f "$CURRENT_DIR/config.json" ]; then
    cp "$CURRENT_DIR/config.json" /var/email-server/
    echo "  ✓ config.json"
fi

if [ -f "$CURRENT_DIR/letter.html" ]; then
    cp "$CURRENT_DIR/letter.html" /var/email-server/
    echo "  ✓ letter.html"
fi

if [ -f "$CURRENT_DIR/warmup-list.txt" ]; then
    cp "$CURRENT_DIR/warmup-list.txt" /var/email-server/
    echo "  ✓ warmup-list.txt"
fi

# Postfix/OpenDKIM configs
for file in main.cf master.cf opendkim.conf signing.table key.table trusted.hosts; do
    if [ -f "$CURRENT_DIR/$file" ]; then
        cp "$CURRENT_DIR/$file" /var/email-server/config/
        echo "  ✓ $file"
    fi
done

# Copy PHP scripts
echo "[4/8] Copying PHP scripts..."

for script in test-email.php send-email.php email-sender.php warmup-scheduler.php; do
    if [ -f "$CURRENT_DIR/$script" ]; then
        cp "$CURRENT_DIR/$script" /var/email-server/scripts/
        chmod +x /var/email-server/scripts/$script
        echo "  ✓ $script"
    fi
done

# Copy composer files
if [ -f "$CURRENT_DIR/composer.json" ]; then
    cp "$CURRENT_DIR/composer.json" /var/email-server/scripts/
    echo "  ✓ composer.json"
fi

# Install PHPMailer if not already installed
echo "[5/8] Checking PHPMailer installation..."
if [ ! -d "/var/email-server/scripts/vendor" ] || [ ! -f "/var/email-server/scripts/vendor/autoload.php" ]; then
    echo "Installing PHPMailer..."
    cd /var/email-server/scripts
    composer install --no-dev --optimize-autoloader 2>/dev/null || {
        echo "Warning: Composer installation failed. Trying to copy existing vendor folder..."
        if [ -d "$CURRENT_DIR/vendor" ]; then
            cp -r "$CURRENT_DIR/vendor" /var/email-server/scripts/
        fi
    }
    cd "$CURRENT_DIR"
else
    echo "  ✓ PHPMailer already installed"
fi

# Set proper permissions
echo "[6/8] Setting permissions..."
chown -R root:root /var/email-server
chmod 755 /var/email-server
chmod 755 /var/email-server/scripts
chmod 644 /var/email-server/config.json 2>/dev/null || true
chmod 644 /var/email-server/letter.html 2>/dev/null || true
chmod 644 /var/email-server/warmup-list.txt 2>/dev/null || true
chmod 644 /var/email-server/config/* 2>/dev/null || true
chmod +x /var/email-server/scripts/*.php 2>/dev/null || true
chmod 755 /var/email-server/logs 2>/dev/null || true

# Update cron job to use correct paths
echo "[7/8] Updating cron job..."

# Check if cron is installed
if ! command -v crontab &> /dev/null; then
    echo "  ⚠ Cron not installed. Installing..."
    apt-get update -qq
    apt-get install -y cron
    systemctl enable cron
    systemctl start cron
    echo "  ✓ Cron installed"
fi

CRON_JOB="*/5 * * * * /usr/bin/php /var/email-server/scripts/warmup-scheduler.php run >> /var/email-server/logs/cron.log 2>&1"
(crontab -l 2>/dev/null | grep -v "warmup-scheduler.php"; echo "$CRON_JOB") | crontab -
echo "  ✓ Cron job updated"

# Verify installation
echo "[8/8] Verifying installation..."

echo ""
echo "Checking files..."

check_file() {
    if [ -f "$1" ]; then
        echo "  ✓ $1"
        return 0
    else
        echo "  ✗ $1 (missing)"
        return 1
    fi
}

check_file "/var/email-server/config.json"
check_file "/var/email-server/letter.html"
check_file "/var/email-server/warmup-list.txt"
check_file "/var/email-server/scripts/email-sender.php"
check_file "/var/email-server/scripts/warmup-scheduler.php"
check_file "/var/email-server/scripts/vendor/autoload.php"

echo ""
echo "======================================"
echo "Migration Complete!"
echo "======================================"
echo ""
echo "File locations:"
echo "  Configuration: /var/email-server/config.json"
echo "  Email template: /var/email-server/letter.html"
echo "  Recipient list: /var/email-server/warmup-list.txt"
echo "  Scripts: /var/email-server/scripts/"
echo "  Logs: /var/email-server/logs/"
echo ""
echo "Backup location: $BACKUP_DIR"
echo ""
echo "Test your setup:"
echo "  1. Check configuration:"
echo "     cat /var/email-server/config.json"
echo ""
echo "  2. Test email sending:"
echo "     php /var/email-server/scripts/email-sender.php single \\"
echo "       your-email@example.com 'Test' /var/email-server/letter.html"
echo ""
echo "  3. Check scheduler status:"
echo "     php /var/email-server/scripts/warmup-scheduler.php status"
echo ""
echo "  4. Force run warmup (test):"
echo "     php /var/email-server/scripts/warmup-scheduler.php force"
echo ""
echo "  5. View logs:"
echo "     tail -f /var/email-server/logs/email-log.txt"
echo ""
echo "Cron job is now set to run every 5 minutes."
echo "Check: crontab -l"
echo ""
