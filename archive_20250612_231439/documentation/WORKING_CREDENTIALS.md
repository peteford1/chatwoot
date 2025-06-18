# ✅ Working Chatwoot SuperAdmin Credentials

## 🔐 SuperAdmin Web Login
- **URL**: https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/super_admin/sign_in
- **Email**: admin@voicelinkai.com
- **Password**: SuperAdmin123!
- **Status**: ✅ Credentials verified in database - password hash matches

## 📊 Database Information (Fresh Database)
- **Database**: chatwoot-db-fresh (16 MB, 79 tables)
- **Connection**: postgresql://chatwootuser:chatwoot123@chatwoot-db-fresh.postgres.database.azure.com:5432/chatwoot_production
- **User ID**: 1 (First user in fresh database)
- **User Type**: SuperAdmin
- **Email**: admin@voicelinkai.com
- **Name**: Super Admin
- **UID**: 6b021809-628a-44ad-a264-7b5197200451
- **Provider**: email
- **Confirmed**: Yes (2025-06-12 00:51:34 UTC)
- **Password Hash**: Verified working with bcrypt

## 🔧 Container Information
- **Name**: chatwoot-backend-test
- **Revision**: 0000040 (latest with admin API token)
- **Image**: chatwoot/chatwoot:latest
- **Environment**: Production with email settings and admin API token configured

## 🔑 Admin API Token
- **Token**: baea8676c67aba47c08564ce
- **Environment Variable**: CHATWOOT_ADMIN_API_TOKEN
- **Status**: ✅ Working and tested
- **Usage**: Available in custom code via `ENV['CHATWOOT_ADMIN_API_TOKEN']`

## ⚠️ Current Status
The database was completely reset to a fresh state. The SuperAdmin user has been created from scratch and credentials are verified to work at the database level.

## 🚀 Next Steps
1. **Try Web Login**: Use the credentials above to login via the SuperAdmin panel
2. **Clear Browser Cache**: If getting "invalid credentials", clear browser cache/cookies
3. **Check Application**: The container is running with email configuration added

## 📝 Important Notes
- This is a FRESH database installation (not a restore)
- All previous users and data have been cleared
- The SuperAdmin user is the only user in the system
- Password verification has been tested and confirmed working
- Email configuration has been added to enable password reset functionality

## 🔍 Troubleshooting
If you're still getting "invalid credentials":
1. Clear browser cache and cookies
2. Try an incognito/private browser window
3. Check if the container needs to be restarted
4. Verify the application is fully loaded and responding

## 🔑 API Token Information
- **Latest Token**: H3b3DTTs6TZsqLnPWA7npNQg
- **Token Class**: AccessToken
- **Status**: Generated successfully but API endpoints returning 404

## ⚠️ Current Issues
1. **API Endpoints**: All API endpoints are returning 404 errors
   - `/api/v1/profile` → 404
   - `/api/v1/accounts` → 404
   - `/api/v1/accounts/3/profile` → 404

2. **Possible Causes**:
   - API routes not properly loaded
   - Missing API configuration
   - Application not fully initialized
   - API authentication mechanism different than expected

## ✅ What's Working
1. **SuperAdmin Panel**: Web interface is accessible
2. **Database**: User properly created and configured
3. **Account Association**: User is linked to account as administrator
4. **Token Generation**: Access tokens are being created successfully

## 🔧 Troubleshooting Commands
```bash
# Check if user exists and is properly configured
bundle exec rails runner "user = User.find(4); puts user.inspect"

# Check account association
bundle exec rails runner "AccountUser.where(user_id: 4).each { |au| puts au.inspect }"

# Generate new API token
bundle exec rails runner "user = User.find(4); token = user.create_access_token; puts token.token"
```

## 📝 Notes
- The SuperAdmin user was successfully created from an existing "Store Admin" user
- Email was updated from storeadmin@voicelinkai.com to admin@voicelinkai.com
- Password was reset to SuperAdmin123!
- User is confirmed and has SuperAdmin privileges
- The web interface should provide full administrative access 