# Cloudflare Free SSL Setup

**Cloudflare provides FREE SSL certificates** with additional benefits like CDN and DDoS protection.

## Step 1: Sign up for Cloudflare (Free)

1. Go to [cloudflare.com](https://cloudflare.com)
2. Create a free account
3. Add your domain `voicelinkai.com`

## Step 2: Update Nameservers

Cloudflare will provide you with nameservers like:
```
alice.ns.cloudflare.com
bob.ns.cloudflare.com
```

Update these at your domain registrar (GoDaddy, Namecheap, etc.)

## Step 3: Configure DNS in Cloudflare

Add an A record:
- **Name**: `@` (root domain)
- **Content**: `51.8.58.201` (your Container Apps IP)
- **Proxy status**: 🧡 Proxied (orange cloud)

## Step 4: SSL/TLS Settings

In Cloudflare dashboard:
1. Go to **SSL/TLS** → **Overview**
2. Set encryption mode to **Full (strict)**
3. Enable **Always Use HTTPS**

## Step 5: Origin Certificates (Optional)

For extra security, create origin certificates:
1. **SSL/TLS** → **Origin Server**
2. **Create Certificate**
3. Download the certificate and key
4. Upload to Azure Container Apps

## Benefits of Cloudflare

- ✅ **Free SSL certificates** (auto-renewing)
- ✅ **CDN** (faster website loading)
- ✅ **DDoS protection**
- ✅ **Analytics**
- ✅ **Security features**
- ✅ **99.9% uptime**

## Result

Your site will have:
- **Trusted SSL certificate** (not self-signed)
- **A+ SSL rating**
- **Faster loading times**
- **Better security** 