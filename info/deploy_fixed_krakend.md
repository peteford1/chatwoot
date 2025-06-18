# 🎯 Deploy Fixed KrakenD Configuration

## ✅ Problem Solved
- **Root Issue:** KrakenD configuration was using deprecated `headers_to_pass` instead of `input_headers`
- **Solution:** Updated all 34 endpoints to use correct `input_headers` parameter
- **Authority:** Official KrakenD v2.10.0 documentation confirms this is correct

## 🚀 Deployment Steps

### 1. Upload Fixed Configuration
```bash
# Upload the corrected krakend.json to your Azure KrakenD instance
# Replace with your actual Azure resource details
scp krakend.json username@voicelinkai.com:/path/to/krakend/
```

### 2. Restart KrakenD Service
```bash
# SSH to your Azure instance and restart KrakenD
ssh username@voicelinkai.com
sudo systemctl restart krakend
# OR if using Docker:
docker restart krakend-container
```

### 3. Test the Fixed Configuration
```bash
# Test authentication through KrakenD (should now work!)
curl -X POST "https://voicelinkai.com/auth/sign_in" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@voicelinkai.com","password":"SuperAdmin123!"}'

# Test profile endpoint (should now work!)  
curl -X GET "https://voicelinkai.com/api/v1/profile" \
  -H "access-token: YOUR_TOKEN" \
  -H "client: YOUR_CLIENT" \
  -H "uid: admin@voicelinkai.com"
```

## 🔍 Expected Results After Fix
- ✅ **Authentication through KrakenD:** Should return 200 with tokens
- ✅ **Profile API through KrakenD:** Should return 200 with user data  
- ✅ **Same behavior** as direct backend calls
- ✅ **Headers properly forwarded** to Chatwoot backend

## 📚 Reference
- **Official Documentation:** https://www.krakend.io/docs/endpoints/parameter-forwarding/
- **Fixed Parameter:** `input_headers` (replaces deprecated `headers_to_pass`)
- **KrakenD Version:** v2.10.0 standards

## 🎉 Success Metrics
When deployment is successful, you should see:
- KrakenD logs showing successful header forwarding
- Authentication working through voicelinkai.com domain  
- Profile API calls returning 200 instead of 401
- Same response times and data as direct backend calls 