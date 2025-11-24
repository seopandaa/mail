#!/bin/bash

echo "======================================"
echo "Add New Domain to Email Server"
echo "======================================"

if [ "$EUID" -ne 0 ]; then
   echo "Please run as root: sudo bash add-domain.sh"
   exit 1
fi

# Check if domain is provided
if [ -z "$1" ]; then
    echo "Usage: sudo bash add-domain.sh DOMAIN_NAME"
    echo ""
    echo "Example:"
    echo "  sudo bash add-domain.sh example.com"
    echo ""
    exit 1
fi

DOMAIN=$1

echo ""
echo "Adding domain: $DOMAIN"
echo ""

# Validate domain format
if ! [[ $DOMAIN =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]?\.[a-zA-Z]{2,}$ ]]; then
    echo "Error: Invalid domain format"
    echo "Please use format: example.com"
    exit 1
fi

echo "[1/6] Creating DKIM directory for $DOMAIN..."
mkdir -p "/etc/opendkim/keys/$DOMAIN"
echo "  ✓ Directory created"

echo ""
echo "[2/6] Generating DKIM keys for $DOMAIN..."
cd "/etc/opendkim/keys/$DOMAIN"
opendkim-genkey -b 2048 -d "$DOMAIN" -D "/etc/opendkim/keys/$DOMAIN" -s mail -v

if [ $? -eq 0 ]; then
    echo "  ✓ DKIM keys generated"
else
    echo "  ✗ Failed to generate DKIM keys"
    exit 1
fi

echo ""
echo "[3/6] Setting DKIM key permissions..."
chown -R opendkim:opendkim "/etc/opendkim/keys/$DOMAIN"
chmod 600 "/etc/opendkim/keys/$DOMAIN/mail.private"
echo "  ✓ Permissions set"

echo ""
echo "[4/6] Adding domain to OpenDKIM signing table..."
if ! grep -q "^*@$DOMAIN" /etc/opendkim/signing.table; then
    echo "*@$DOMAIN    mail._domainkey.$DOMAIN" >> /etc/opendkim/signing.table
    echo "  ✓ Added to signing.table"
else
    echo "  - Already in signing.table"
fi

echo ""
echo "[5/6] Adding domain to OpenDKIM key table..."
if ! grep -q "^mail._domainkey.$DOMAIN" /etc/opendkim/key.table; then
    echo "mail._domainkey.$DOMAIN    $DOMAIN:mail:/etc/opendkim/keys/$DOMAIN/mail.private" >> /etc/opendkim/key.table
    echo "  ✓ Added to key.table"
else
    echo "  - Already in key.table"
fi

echo ""
echo "[6/6] Restarting services..."
systemctl restart opendkim
echo "  ✓ OpenDKIM restarted"

systemctl restart postfix
echo "  ✓ Postfix restarted"

echo ""
echo "======================================"
echo "Domain Added Successfully!"
echo "======================================"
echo ""
echo "Domain: $DOMAIN"
echo "DKIM Selector: mail"
echo ""
echo "======================================"
echo "DNS Records Required"
echo "======================================"
echo ""
echo "Add these DNS records for $DOMAIN:"
echo ""

echo "1. MX Record:"
echo "   Type: MX"
echo "   Name: @"
echo "   Value: $DOMAIN"
echo "   Priority: 10"
echo ""

echo "2. A Record (if not already set):"
echo "   Type: A"
echo "   Name: @"
echo "   Value: YOUR_SERVER_IP"
echo ""

echo "3. SPF Record:"
echo "   Type: TXT"
echo "   Name: @"
echo "   Value: v=spf1 ip4:YOUR_SERVER_IP -all"
echo ""

echo "4. DKIM Record:"
echo "   Type: TXT"
echo "   Name: mail._domainkey"
echo "   Value:"
echo ""
cat "/etc/opendkim/keys/$DOMAIN/mail.txt"
echo ""

echo "5. DMARC Record:"
echo "   Type: TXT"
echo "   Name: _dmarc"
echo "   Value: v=DMARC1; p=quarantine; rua=mailto:postmaster@$DOMAIN"
echo ""

echo "======================================"
echo "Save DKIM Public Key"
echo "======================================"
echo ""
echo "Your DKIM public key has been saved to:"
echo "  /etc/opendkim/keys/$DOMAIN/mail.txt"
echo ""
echo "View it anytime with:"
echo "  cat /etc/opendkim/keys/$DOMAIN/mail.txt"
echo ""

echo "======================================"
echo "Next Steps"
echo "======================================"
echo ""
echo "1. Add the DNS records above to your domain"
echo "2. Wait 1-6 hours for DNS propagation"
echo "3. Verify DNS with:"
echo "   nslookup -type=mx $DOMAIN"
echo "   nslookup -type=txt mail._domainkey.$DOMAIN"
echo ""
echo "4. Add domain to config.json:"
echo "   nano /var/email-server/config.json"
echo ""
echo "   Add this to 'domains' array:"
echo '   {'
echo '     "domain": "'$DOMAIN'",'
echo '     "name": "Your Company Name",'
echo '     "sender_email": "noreply@'$DOMAIN'",'
echo '     "sender_name": "Your Company",'
echo '     "reply_to_email": "support@'$DOMAIN'",'
echo '     "reply_to_name": "Support Team",'
echo '     "enabled": true,'
echo '     "is_default": false'
echo '   }'
echo ""
echo "5. Test email from new domain:"
echo "   php send.php --domain $DOMAIN"
echo ""
