# Production Email Server Setup for fx.avameta.dev

Complete, production-ready email server with automated warmup system using Postfix, OpenDKIM, and PHPMailer.

## Quick Start - Send Bulk Emails

### Super Simple Method

```bash
php send.php
```

That's it! The script automatically:
- Loads recipients from `email-list.txt`
- Uses template from `letter.html`
- Applies settings from `config.json`
- Sends all emails with confirmation

### Initial Setup

```bash
# 1. Upload all files to your VPS
scp -r * root@YOUR_VPS_IP:/root/email-server-setup/

# 2. SSH into your VPS
ssh root@YOUR_VPS_IP

# 3. Navigate to setup directory
cd /root/email-server-setup

# 4. Make scripts executable
chmod +x setup-server.sh install.sh setup-cron.sh

# 5. Run initial setup
sudo bash setup-server.sh

# 6. Get DKIM key for DNS
sudo cat /etc/opendkim/keys/fx.avameta.dev/mail.txt

# 7. Configure DNS records (see DNS-RECORDS.txt)

# 8. Test basic email
sudo php /var/email-server/scripts/test-email.php
```

### Warmup System Setup

```bash
# 1. Install warmup automation
sudo bash setup-cron.sh

# 2. Configure settings
sudo nano /var/email-server/config.json

# 3. Add recipient emails
sudo nano /var/email-server/warmup-list.txt

# 4. Test warmup campaign
php /var/email-server/scripts/warmup-scheduler.php force

# 5. Check status
php /var/email-server/scripts/warmup-scheduler.php status
```

## What's Included

### Core Email Server
- **Postfix Configuration**: Complete MTA setup with security restrictions
- **OpenDKIM**: DKIM signing for email authentication
- **PHPMailer**: Library for sending emails via PHP
- **DNS Templates**: Exact DNS records to configure

### Warmup & Automation System
- **Automated Scheduling**: Send warmup emails 5 times per day
- **Configuration Management**: Centralized settings in config.json
- **Template System**: HTML templates with variable support
- **Recipient Management**: Easy-to-manage email lists
- **Rate Limiting**: Prevent spam flags with controlled sending
- **Comprehensive Logging**: Track all email activity
- **Bulk Sending**: Send to multiple recipients efficiently

### Documentation
- **DEPLOYMENT-GUIDE.txt**: Initial server setup
- **WARMUP-GUIDE.txt**: Complete warmup system guide
- **UPGRADE-INSTRUCTIONS.txt**: Upgrade from basic to advanced
- **DNS-RECORDS.txt**: DNS configuration
- **CHANGES-SUMMARY.txt**: What's new in this version

## Files Overview

### Setup Scripts
| File | Purpose |
|------|---------|
| `setup-server.sh` | Initial email server deployment |
| `setup-cron.sh` | Warmup automation setup |
| `install.sh` | Package installation |

### Configuration Files
| File | Purpose |
|------|---------|
| `config.json` | Centralized settings (sender, schedule, limits) |
| `main.cf` | Postfix main configuration |
| `master.cf` | Postfix service definitions |
| `opendkim.conf` | OpenDKIM configuration |
| `letter.html` | Email template for warmup |
| `warmup-list.txt` | Recipient email list |

### PHP Scripts
| File | Purpose |
|------|---------|
| `test-email.php` | Simple email test |
| `send-email.php` | Basic email sending |
| `email-sender.php` | Advanced bulk sender with templates |
| `warmup-scheduler.php` | Automated warmup scheduler |

### Documentation
| File | Purpose |
|------|---------|
| `README.md` | This file - quick start guide |
| `DEPLOYMENT-GUIDE.txt` | Complete deployment steps |
| `WARMUP-GUIDE.txt` | Warmup system documentation |
| `UPGRADE-INSTRUCTIONS.txt` | Upgrade guide |
| `CHANGES-SUMMARY.txt` | What's new |
| `DNS-RECORDS.txt` | DNS configuration |

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

### Simple Bulk Send (Recommended)

**Just run:**
```bash
php send.php
```

**Setup files first:**
```bash
# Add recipients (one email per line)
nano /var/email-server/email-list.txt

# Edit email template
nano /var/email-server/letter.html

# Configure settings
nano /var/email-server/config.json
```

### Alternative Methods

**Test Email:**
```bash
sudo php /var/email-server/scripts/test-email.php
```

**Single Email:**
```bash
php /var/email-server/scripts/email-sender.php single \
  "recipient@example.com" \
  "Subject Line" \
  "/var/email-server/letter.html"
```

**Manual Bulk Send:**
```bash
php /var/email-server/scripts/email-sender.php bulk \
  "/var/email-server/warmup-list.txt" \
  "/var/email-server/letter.html" \
  "Optional Subject"
```

### Automated Warmup

**Check Status:**
```bash
php /var/email-server/scripts/warmup-scheduler.php status
```

**Force Run:**
```bash
php /var/email-server/scripts/warmup-scheduler.php force
```

**View Logs:**
```bash
tail -f /var/email-server/logs/email-log.txt
tail -f /var/email-server/logs/warmup-scheduler.log
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

- **Configuration**: `/var/email-server/config.json`
- **Email Template**: `/var/email-server/letter.html`
- **Recipient List**: `/var/email-server/warmup-list.txt`
- **Scripts**: `/var/email-server/scripts/`
- **Logs**: `/var/email-server/logs/`
- **DKIM Keys**: `/etc/opendkim/keys/fx.avameta.dev/`
- **Postfix Config**: `/etc/postfix/`

## Key Features

### Automated Warmup System
- Runs 5 times per day at scheduled intervals
- Configurable send times (default: 9am, 11:30am, 2pm, 4:30pm, 7pm)
- Random subject line rotation
- Rate limiting to prevent spam flags
- Daily send tracking

### Easy Configuration
Edit `/var/email-server/config.json`:
- Sender name and email
- Reply-to address
- Send schedule and frequency
- Subject line variations
- Rate limits

### Comprehensive Logging
- Email sending log: `/var/email-server/logs/email-log.txt`
- Scheduler log: `/var/email-server/logs/warmup-scheduler.log`
- Cron execution log: `/var/email-server/logs/cron.log`

## Complete Documentation

For detailed guides, see these files:
- **WARMUP-GUIDE.txt** - Complete warmup system documentation
- **UPGRADE-INSTRUCTIONS.txt** - How to upgrade existing setup
- **DEPLOYMENT-GUIDE.txt** - Initial server deployment
- **CHANGES-SUMMARY.txt** - What's new in this version
- **DNS-RECORDS.txt** - DNS configuration
- **DIRECTORY-STRUCTURE.txt** - File system layout

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
