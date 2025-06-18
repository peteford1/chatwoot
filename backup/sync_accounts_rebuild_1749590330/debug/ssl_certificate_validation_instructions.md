# SSL Certificate TXT Validation Instructions
**Date:** 2025-06-10 08:26 UTC  
**Certificate:** voicelinkai-cert-txt  
**Domain:** voicelinkai.com

## 🔑 Required TXT Record

Azure requires the following TXT record to be added to validate domain ownership:

### DNS Record to Add:
```
Record Type: TXT
Name: _acme-challenge.voicelinkai.com
Value: _zaixgnr94wxwaq56a31wdr77v2rmily
TTL: 300 (or minimum allowed)
```

## 📋 Steps to Add TXT Record:

### 1. Log into your DNS provider
- This is where you manage DNS for voicelinkai.com
- Could be your domain registrar, Cloudflare, Route53, etc.

### 2. Add the TXT record:
- **Host/Name:** `_acme-challenge.voicelinkai.com` OR just `_acme-challenge` 
- **Type:** TXT
- **Value:** `_zaixgnr94wxwaq56a31wdr77v2rmily`
- **TTL:** 300 seconds (5 minutes)

### 3. Wait for DNS propagation
- Usually takes 5-15 minutes
- Can verify with: `dig TXT _acme-challenge.voicelinkai.com`

## 🧪 Validation Commands

After adding the TXT record, use these commands to verify:

```bash
# Check if TXT record is propagated
dig TXT _acme-challenge.voicelinkai.com

# Should return the validation token
nslookup -type=TXT _acme-challenge.voicelinkai.com
```

## 🔄 After Adding the Record

Once the TXT record is added and propagated:

1. **Check certificate status:**
```bash
az containerapp env certificate list --name chatwoot-env-test --resource-group SM-Test --query "[?name=='voicelinkai-cert-txt'].properties.provisioningState" --output table
```

2. **Bind certificate when it's ready:**
```bash
# Get certificate ID
CERT_ID=$(az containerapp env certificate list --name chatwoot-env-test --resource-group SM-Test --query "[?name=='voicelinkai-cert-txt'].id" --output tsv)

# Bind to hostname
az containerapp hostname bind --hostname voicelinkai.com --resource-group SM-Test --name chatwoot-backend-test --certificate "$CERT_ID"
```

3. **Test HTTPS access:**
```bash
curl -I https://voicelinkai.com
```

## 📊 Current Status
- ✅ Certificate created: voicelinkai-cert-txt
- ⏳ Waiting for TXT record: _zaixgnr94wxwaq56a31wdr77v2rmily
- 🔄 Next step: Add TXT record to DNS
- 🎯 Final step: Bind certificate to Container App

## 🚨 Important Notes
- The validation token is time-sensitive
- Don't delete the TXT record until certificate is fully validated and bound
- DNS propagation can take up to 1 hour in some cases
- If validation fails, we may need to generate a new token 