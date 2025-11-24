#!/bin/bash

echo "======================================"
echo "Email Server Domains"
echo "======================================"
echo ""

CONFIG_FILE="/var/email-server/config.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found: $CONFIG_FILE"
    exit 1
fi

# Check if multi-domain format
if grep -q '"domains"' "$CONFIG_FILE"; then
    echo "Configuration: Multi-domain"
    echo ""

    # Parse domains from JSON
    DOMAIN_COUNT=$(php -r "
        \$config = json_decode(file_get_contents('$CONFIG_FILE'), true);
        echo count(\$config['domains']);
    ")

    echo "Total domains: $DOMAIN_COUNT"
    echo ""

    for ((i=0; i<$DOMAIN_COUNT; i++)); do
        DOMAIN=$(php -r "
            \$config = json_decode(file_get_contents('$CONFIG_FILE'), true);
            echo \$config['domains'][$i]['domain'];
        ")

        NAME=$(php -r "
            \$config = json_decode(file_get_contents('$CONFIG_FILE'), true);
            echo \$config['domains'][$i]['name'];
        ")

        EMAIL=$(php -r "
            \$config = json_decode(file_get_contents('$CONFIG_FILE'), true);
            echo \$config['domains'][$i]['sender_email'];
        ")

        ENABLED=$(php -r "
            \$config = json_decode(file_get_contents('$CONFIG_FILE'), true);
            echo \$config['domains'][$i]['enabled'] ? 'Yes' : 'No';
        ")

        IS_DEFAULT=$(php -r "
            \$config = json_decode(file_get_contents('$CONFIG_FILE'), true);
            echo (isset(\$config['domains'][$i]['is_default']) && \$config['domains'][$i]['is_default']) ? 'Yes' : 'No';
        ")

        NUM=$((i+1))
        echo "[$NUM] $DOMAIN"
        echo "    Name: $NAME"
        echo "    From: $EMAIL"
        echo "    Enabled: $ENABLED"
        echo "    Default: $IS_DEFAULT"

        # Check DKIM key
        if [ -f "/etc/opendkim/keys/$DOMAIN/mail.private" ]; then
            echo "    DKIM: ✓ Configured"
        else
            echo "    DKIM: ✗ Missing"
        fi

        echo ""
    done

else
    echo "Configuration: Single domain (legacy)"
    echo ""

    DOMAIN=$(php -r "
        \$config = json_decode(file_get_contents('$CONFIG_FILE'), true);
        \$email = \$config['email_settings']['sender_email'];
        echo explode('@', \$email)[1];
    ")

    NAME=$(php -r "
        \$config = json_decode(file_get_contents('$CONFIG_FILE'), true);
        echo \$config['email_settings']['sender_name'];
    ")

    EMAIL=$(php -r "
        \$config = json_decode(file_get_contents('$CONFIG_FILE'), true);
        echo \$config['email_settings']['sender_email'];
    ")

    echo "Domain: $DOMAIN"
    echo "Name: $NAME"
    echo "From: $EMAIL"

    if [ -f "/etc/opendkim/keys/$DOMAIN/mail.private" ]; then
        echo "DKIM: ✓ Configured"
    else
        echo "DKIM: ✗ Missing"
    fi

    echo ""
fi

echo "======================================"
echo "DKIM Keys Installed"
echo "======================================"
echo ""

if [ -d "/etc/opendkim/keys" ]; then
    for domain_dir in /etc/opendkim/keys/*/; do
        if [ -d "$domain_dir" ]; then
            domain=$(basename "$domain_dir")
            if [ -f "$domain_dir/mail.private" ]; then
                echo "✓ $domain"
                echo "  Private key: $domain_dir/mail.private"
                echo "  Public key:  $domain_dir/mail.txt"
            fi
        fi
    done
else
    echo "No DKIM keys directory found"
fi

echo ""
echo "======================================"
echo "Quick Actions"
echo "======================================"
echo ""
echo "Add new domain:"
echo "  sudo bash /mail/add-domain.sh DOMAIN.com"
echo ""
echo "Send emails (select domain):"
echo "  php send-multi.php"
echo ""
echo "Send from specific domain:"
echo "  php send-multi.php --domain DOMAIN.com"
echo ""
echo "View DKIM key:"
echo "  cat /etc/opendkim/keys/DOMAIN.com/mail.txt"
echo ""
