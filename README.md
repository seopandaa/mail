# Production Email Server Setup for fx.avameta.dev

Complete, production-ready email server configuration using Postfix, OpenDKIM, and PHPMailer.

## Quick Start

```bash
# 1. Upload all files to your VPS
scp -r * root@YOUR_VPS_IP:/root/email-server-setup/

# 2. SSH into your VPS
ssh root@YOUR_VPS_IP

# 3. Navigate to setup directory
cd /root/email-server-setup

# 4. Make scripts executable
chmod +x setup-server.sh install.sh

# 5. Run setup
sudo bash setup-server.sh

# 6. Get DKIM key for DNS
sudo cat /etc/opendkim/keys/fx.avameta.dev/mail.txt

# 7. Configure DNS records (see DNS-RECORDS.txt)

# 8. Test email
sudo php /var/email-server/scripts/test-email.php
```

## What's Included

- **Postfix Configuration**: Complete MTA setup with security restrictions
- **OpenDKIM**: DKIM signing for email authentication
- **PHPMailer**: Library for sending emails via PHP
- **Test Scripts**: Verify your setup works correctly
- **DNS Templates**: Exact DNS records to configure
- **Documentation**: Complete deployment and troubleshooting guides

## Files Overview

| File | Purpose |
|------|---------|
| `setup-server.sh` | Main deployment script - runs everything |
| `install.sh` | Package installation and service configuration |
| `main.cf` | Postfix main configuration |
| `master.cf` | Postfix service definitions |
| `opendkim.conf` | OpenDKIM configuration |
| `test-email.php` | Test email sending |
| `send-email.php` | Production email script |
| `DNS-RECORDS.txt` | DNS configuration values |
| `DEPLOYMENT-GUIDE.txt` | Step-by-step deployment instructions |

## Requirements

- Ubuntu VPS (18.04, 20.04, 22.04, or newer)
- Root access
- Domain pointed to VPS IP (fx.avameta.dev)
- Ports 25, 587, 465 open

## Post-Installation

After running setup, you must:

1. **Get DKIM Key**: `sudo cat /etc/opendkim/keys/fx.avameta.dev/mail.txt`
2. **Configure DNS**: Add MX, SPF, DKIM, DMARC records (see DNS-RECORDS.txt)
3. **Set PTR Record**: Contact VPS provider for reverse DNS
4. **Wait for DNS**: Allow 1-6 hours for propagation
5. **Test**: Run `sudo php /var/email-server/scripts/test-email.php`

## Sending Emails

**Test Email:**
```bash
sudo php /var/email-server/scripts/test-email.php
```

**Custom Email:**
```bash
sudo php /var/email-server/scripts/send-email.php \
  "recipient@example.com" \
  "Recipient Name" \
  "Subject Line" \
  "<h1>Hello</h1><p>Email body</p>"
```

## Testing Deliverability

1. Visit https://www.mail-tester.com/
2. Send email to provided address
3. Check your score (target: 8/10+)

```bash
sudo php /var/email-server/scripts/send-email.php \
  "test-xxxxx@srv1.mail-tester.com" \
  "Tester" \
  "Deliverability Test" \
  "<p>Testing server</p>"
```

## Troubleshooting

**Check Services:**
```bash
sudo systemctl status postfix
sudo systemctl status opendkim
```

**View Logs:**
```bash
sudo tail -f /var/log/postfix.log
```

**Restart Services:**
```bash
sudo systemctl restart postfix opendkim
```

**Test Configuration:**
```bash
sudo postfix check
```

**Verify DNS:**
```bash
nslookup -type=mx fx.avameta.dev
nslookup -type=txt mail._domainkey.fx.avameta.dev
```

## Security

**Firewall:**
```bash
sudo ufw allow 25/tcp
sudo ufw allow 587/tcp
sudo ufw allow 465/tcp
sudo ufw enable
```

**Keep Updated:**
```bash
sudo apt update && sudo apt upgrade -y
```

## File Locations

- **Scripts**: `/var/email-server/scripts/`
- **Config**: `/var/email-server/config/`
- **DKIM Keys**: `/etc/opendkim/keys/fx.avameta.dev/`
- **Postfix Config**: `/etc/postfix/`
- **Logs**: `/var/log/postfix.log`

## Documentation

- `DEPLOYMENT-GUIDE.txt` - Complete step-by-step deployment
- `DNS-RECORDS.txt` - DNS configuration details
- `DIRECTORY-STRUCTURE.txt` - File system layout

## Support

For issues:
1. Check service status and logs
2. Verify DNS propagation
3. Confirm PTR record configured
4. Test with mail-tester.com
5. Check firewall settings

---

**Domain**: fx.avameta.dev
**Server Type**: Production Email Server
**Technologies**: Postfix, OpenDKIM, PHPMailer
