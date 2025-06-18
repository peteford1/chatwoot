# Let's Encrypt SSL Setup for www.voicelinkai.com

**Date:** January 5, 2025 01:20 AM  
**Domain:** www.voicelinkai.com + voicelinkai.com  
**Azure Resource Group:** SM-Test  
**Azure Gateway:** voicelinkai-gateway  

## Prerequisites Verification

### DNS Requirements
1. **Domain must resolve** to Azure Gateway IP
2. **Port 80 must be open** for ACME challenge
3. **Azure Gateway must be accessible** and properly configured

### Check Command
```bash
./check-domain-dns.sh
```

## SSL Certificate Generation Process

### Step 1: Run DNS Verification
```bash
# Verify domain is properly configured
./check-domain-dns.sh
```

### Step 2: Generate Let's Encrypt Certificate
```bash
# Run as root/sudo (requires system access)
sudo ./setup-letsencrypt-voicelinkai.sh
```

### Step 3: Upload to Azure
```bash
# Generated automatically by main script
./upload-ssl-to-azure.sh
```

## Key Files Generated

| File | Purpose | Location |
|------|---------|----------|
| `fullchain.pem` | SSL Certificate | `/etc/letsencrypt/live/www.voicelinkai.com/` |
| `privkey.pem` | Private Key | `/etc/letsencrypt/live/www.voicelinkai.com/` |
| `voicelinkai-ssl.pfx` | Azure Format Certificate | `/tmp/voicelinkai-ssl.pfx` |
| `upload-ssl-to-azure.sh` | Azure Upload Script | Current directory |
| `verify-ssl.sh` | SSL Verification Script | Current directory |

## Azure Configuration Commands

### Upload Certificate to Application Gateway
```bash
az network application-gateway ssl-cert create \
    --resource-group SM-Test \
    --gateway-name voicelinkai-gateway \
    --name voicelinkai-ssl-cert \
    --cert-file /tmp/voicelinkai-ssl.pfx \
    --cert-password VoiceLinkAI2025!
```

### Update HTTPS Listener
```bash
az network application-gateway http-listener update \
    --resource-group SM-Test \
    --gateway-name voicelinkai-gateway \
    --name httpsListener \
    --ssl-cert voicelinkai-ssl-cert
```

## Auto-Renewal Configuration

### Cron Job Added
```bash
0 12 * * * /usr/bin/certbot renew --quiet --post-hook 'bash /path/to/upload-ssl-to-azure.sh'
```

### Manual Renewal Test
```bash
# Test renewal (dry run)
sudo certbot renew --dry-run

# Force renewal
sudo certbot renew --force-renewal
```

## Verification Steps

### 1. Certificate Validation
```bash
# Check certificate details
./verify-ssl.sh

# Manual certificate check
openssl x509 -in /etc/letsencrypt/live/www.voicelinkai.com/fullchain.pem -noout -dates
```

### 2. Website Testing
```bash
# Test HTTPS access
curl -I https://www.voicelinkai.com
curl -I https://voicelinkai.com

# Check SSL grade
# Visit: https://www.ssllabs.com/ssltest/
```

## Security Configuration

### Certificate Details
- **Algorithm:** RSA 2048-bit or ECDSA 256-bit
- **Validity:** 90 days (auto-renewed at 60 days)
- **Issuer:** Let's Encrypt Authority X3
- **SAN:** www.voicelinkai.com, voicelinkai.com

### PFX Password
```
Password: VoiceLinkAI2025!
Location: /tmp/voicelinkai-ssl.pfx
```

**⚠️ Keep this password secure and change it in production!**

## Troubleshooting

### Common Issues

#### DNS Not Resolving
**Symptoms:** `nslookup` fails for domain
**Solution:** 
1. Check domain registrar DNS settings
2. Verify A record points to Azure Gateway IP
3. Wait 5-60 minutes for DNS propagation

#### Port 80 Not Accessible
**Symptoms:** HTTP test fails in verification
**Solution:**
1. Check Azure NSG rules allow port 80
2. Verify Application Gateway HTTP listener is configured
3. Check backend pool health

#### Certificate Generation Fails
**Symptoms:** `certbot` returns error
**Solution:**
1. Run with `--dry-run` flag first
2. Check `/var/log/letsencrypt/letsencrypt.log`
3. Verify domain ownership via webroot challenge

#### Azure Upload Fails
**Symptoms:** `az network application-gateway` command fails
**Solution:**
1. Verify Azure CLI is logged in: `az account show`
2. Check resource group and gateway names
3. Verify PFX file exists and password is correct

## Post-Installation Checklist

- [ ] Certificate generated successfully
- [ ] PFX file created for Azure
- [ ] Certificate uploaded to Azure Gateway
- [ ] HTTPS listener updated
- [ ] Auto-renewal cron job configured
- [ ] Website accessible via HTTPS
- [ ] HTTP redirects to HTTPS
- [ ] SSL test passes (SSLLabs grade A)

## Monitoring & Maintenance

### Certificate Expiry Monitoring
```bash
# Check expiry date
openssl x509 -in /etc/letsencrypt/live/www.voicelinkai.com/fullchain.pem -noout -dates

# Set up expiry alerts (30 days before)
# Add to monitoring system or create separate script
```

### Log Locations
- Let's Encrypt logs: `/var/log/letsencrypt/`
- Cron logs: `/var/log/cron` or `/var/log/syslog`
- Azure Gateway logs: Azure Portal > Application Gateway > Diagnostics

## Emergency Procedures

### Certificate Revocation
```bash
# If certificate is compromised
sudo certbot revoke --cert-path /etc/letsencrypt/live/www.voicelinkai.com/fullchain.pem
```

### Backup Certificate
```bash
# Create backup of certificate files
sudo tar -czf letsencrypt-backup-$(date +%Y%m%d).tar.gz /etc/letsencrypt/
```

### Rollback Plan
1. Revert to previous certificate in Azure Gateway
2. Update DNS to point to backup server if needed
3. Generate new certificate from clean slate if required

## Status
✅ **CONFIGURED** - Scripts created and ready for execution
⏳ **PENDING** - Awaiting domain DNS configuration and script execution 