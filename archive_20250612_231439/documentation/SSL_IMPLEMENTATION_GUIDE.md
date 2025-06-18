# 🔐 SSL Implementation Guide for voicelinkai.com

## 🎯 Goal
Properly configure SSL certificates so that `https://voicelinkai.com` works without handshake errors.

## 📋 Current Situation
- **Domain**: `voicelinkai.com` resolves to Azure Container Apps IP
- **Issue**: KrakenD gateway expects SSL certificates that don't exist
- **Workaround**: Using direct Azure Container Apps URLs

## 🛠️ Implementation Options

### Option 1: Azure Container Apps Custom Domain (RECOMMENDED)
**Complexity**: ⭐⭐ (Medium)  
**Cost**: Free SSL certificates  
**Maintenance**: Low  

#### Steps:
1. **Add Custom Domain to Container App**
   ```bash
   az containerapp hostname add \
     --name voicelinkai-gateway-instance-v32 \
     --resource-group SM-Test \
     --hostname voicelinkai.com
   ```

2. **Configure DNS**
   ```bash
   # Get the verification domain
   az containerapp hostname show \
     --name voicelinkai-gateway-instance-v32 \
     --resource-group SM-Test \
     --hostname voicelinkai.com
   ```

3. **Add DNS Records**
   - **CNAME**: `voicelinkai.com` → `voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io`
   - **TXT**: Domain verification record (provided by Azure)

4. **Enable Managed Certificate**
   ```bash
   az containerapp hostname bind \
     --name voicelinkai-gateway-instance-v32 \
     --resource-group SM-Test \
     --hostname voicelinkai.com \
     --environment-certificate-id managed
   ```

5. **Remove TLS from KrakenD Config**
   - Deploy the `krakend-no-ssl.json` configuration
   - Let Azure handle SSL termination

---

### Option 2: Let's Encrypt with Certbot
**Complexity**: ⭐⭐⭐ (High)  
**Cost**: Free  
**Maintenance**: Medium (renewal needed)  

#### Steps:
1. **Install Certbot**
   ```bash
   # On your local machine or a VM
   sudo apt-get install certbot
   ```

2. **Generate Certificate**
   ```bash
   certbot certonly --manual \
     --preferred-challenges dns \
     -d voicelinkai.com
   ```

3. **Add DNS TXT Record** (as instructed by certbot)

4. **Upload Certificates to Azure**
   ```bash
   # Create certificate in Azure Container Apps
   az containerapp env certificate upload \
     --name <environment-name> \
     --resource-group SM-Test \
     --certificate-file /etc/letsencrypt/live/voicelinkai.com/fullchain.pem \
     --certificate-key-file /etc/letsencrypt/live/voicelinkai.com/privkey.pem \
     --certificate-name voicelinkai-com-cert
   ```

5. **Bind Certificate to Domain**
   ```bash
   az containerapp hostname bind \
     --name voicelinkai-gateway-instance-v32 \
     --resource-group SM-Test \
     --hostname voicelinkai.com \
     --environment-certificate-id <certificate-id>
   ```

---

### Option 3: Cloudflare SSL (EASIEST)
**Complexity**: ⭐ (Easy)  
**Cost**: Free  
**Maintenance**: None  

#### Steps:
1. **Add Domain to Cloudflare**
   - Sign up at cloudflare.com
   - Add `voicelinkai.com` as a site

2. **Update Nameservers**
   - Point your domain's nameservers to Cloudflare

3. **Configure DNS in Cloudflare**
   ```
   Type: CNAME
   Name: @
   Target: voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io
   Proxy: Enabled (orange cloud)
   ```

4. **Enable SSL in Cloudflare**
   - SSL/TLS → Overview → Full (strict)
   - Edge Certificates → Always Use HTTPS: On

5. **Remove TLS from KrakenD**
   - Deploy `krakend-no-ssl.json`
   - Cloudflare handles SSL termination

---

## 🚀 Quick Implementation (Option 1 - Recommended)

Let me create a script to implement Option 1:

```bash
#!/bin/bash
# ssl_setup.sh

echo "🔐 Setting up SSL for voicelinkai.com..."

# Step 1: Add custom domain
echo "📝 Adding custom domain..."
az containerapp hostname add \
  --name voicelinkai-gateway-instance-v32 \
  --resource-group SM-Test \
  --hostname voicelinkai.com

# Step 2: Get verification info
echo "🔍 Getting DNS verification info..."
az containerapp hostname show \
  --name voicelinkai-gateway-instance-v32 \
  --resource-group SM-Test \
  --hostname voicelinkai.com

echo "📋 Next steps:"
echo "1. Add the CNAME record to your DNS"
echo "2. Add the TXT record for verification"
echo "3. Run: az containerapp hostname bind --name voicelinkai-gateway-instance-v32 --resource-group SM-Test --hostname voicelinkai.com --environment-certificate-id managed"
```

## 📊 Comparison

| Option | Complexity | Cost | Auto-Renewal | Setup Time |
|--------|------------|------|--------------|------------|
| Azure Custom Domain | Medium | Free | Yes | 30 mins |
| Let's Encrypt | High | Free | Manual | 1-2 hours |
| Cloudflare | Easy | Free | Yes | 15 mins |

## 🎯 Recommended Approach

**For Production**: Use **Option 1 (Azure Custom Domain)** because:
- ✅ Native Azure integration
- ✅ Automatic certificate renewal
- ✅ No external dependencies
- ✅ Free SSL certificates
- ✅ Proper enterprise setup

**For Quick Testing**: Use **Option 3 (Cloudflare)** because:
- ✅ Fastest setup (15 minutes)
- ✅ No Azure configuration needed
- ✅ Works immediately
- ✅ Great for development/testing

## 🔧 Implementation Script

Would you like me to create a script to implement any of these options? I can:

1. **Create Azure Custom Domain setup script**
2. **Create Cloudflare setup instructions**
3. **Fix the current KrakenD SSL configuration**

## 💡 Immediate Action

The fastest path to working SSL:
1. **Use Cloudflare** (15 minutes setup)
2. **Deploy SSL-free KrakenD** (remove TLS config)
3. **Test with your frontend**

This gets you working SSL today while we can implement the proper Azure solution later. 