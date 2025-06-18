# SSL Certificate Setup Instructions

## 🎉 GOOD NEWS: SSL Certificate Created Successfully!

**Certificate ID:** `/subscriptions/535e2aa8-27e9-4d89-9208-be446ef89b87/resourceGroups/SM-Test/providers/Microsoft.App/managedEnvironments/chatwoot-env-test/managedCertificates/voicelinkai-cert-txt`

## 📋 Required DNS Records

### 1. Add TXT Record for SSL Validation
- **Name:** `_acme-challenge.voicelinkai.com`
- **Value:** `_8w1uni6yymqmnjy8c54hwfeknert97r`
- **TTL:** 300 seconds (5 minutes)

### 2. (Optional) Fix A Record for Better Performance
- **Name:** `voicelinkai.com`
- **Current Value:** `64.227.102.80`
- **Recommended Value:** `51.8.58.201`

## 🚀 Next Steps

1. **Add the TXT record to your DNS provider**
2. **Wait 5-10 minutes for DNS propagation**
3. **Run the certificate binding command:**
   ```bash
   ./configure_azure_domain.sh
   ```
4. **Verify SSL is working:**
   ```bash
   curl -I https://voicelinkai.com/api/backend/status
   ```

## 🔍 DNS Verification Commands

```bash
# Check if TXT record is propagated
dig TXT _acme-challenge.voicelinkai.com

# Check current A record
dig A voicelinkai.com

# Check certificate status
az containerapp env certificate show \
  --name chatwoot-env-test \
  --resource-group SM-Test \
  --certificate-name voicelinkai-cert-txt
```

## 🔧 Troubleshooting

If the certificate binding fails:
1. Check certificate status (may take a few minutes to validate)
2. Verify TXT record exists and is correct
3. Wait for DNS propagation
4. Re-run the script

## 📞 Status Check

The certificate is created but needs DNS validation to become active. Once you add the TXT record, the certificate should automatically validate within 5-10 minutes. 