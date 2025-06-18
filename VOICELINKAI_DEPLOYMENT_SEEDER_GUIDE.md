# VoiceLinkAI Deployment Seeder Guide

**Created:** #{Time.current}  
**Purpose:** Complete setup of VoiceLinkAI account structure during deployment  
**Scripts:** `scripts/deployment_seeder_rails.rb` (primary), `scripts/deployment_seeder.rb` (standalone)

## 🎯 What This Seeder Creates

### **Account Structure**
- **Account:** `voicelinkai` (dedicated account for VoiceLinkAI operations)
- **Super Admin:** `admin@voicelinkai.com` (system-wide privileges + account administrator)
- **Store Admin:** `storeadmin@voicelinkai.com` (account administrator)
- **Twilio Inbox:** SMS channel for customer communications (if credentials provided)

### **Tokens Generated**
- **Platform Token:** For account/user management via Platform API
- **Super Admin Token:** Primary admin token for environment configuration
- **Store Admin Token:** Secondary admin token for store operations

### **Role Clarification**
Based on database analysis:

| Role | Scope | Permissions |
|------|-------|------------|
| **SuperAdmin** | System-wide | Access to all accounts, system settings, deployment management |
| **Account Administrator** | Account-level | Manage conversations, contacts, inboxes, agents, account settings |
| **Account Agent** | Account-level | Handle conversations, manage contacts (limited access) |

## 🚀 Deployment Usage

### **Option 1: Rails Runner (Recommended)**
```bash
# Basic usage (uses default URL from ENV['FRONTEND_URL'] or localhost:3000)
bundle exec rails runner scripts/deployment_seeder_rails.rb

# With custom URL
bundle exec rails runner scripts/deployment_seeder_rails.rb https://your-deployment-url.com
```

### **Option 2: Standalone Script**
```bash
# Basic usage
ruby scripts/deployment_seeder.rb

# With custom URL  
ruby scripts/deployment_seeder.rb https://your-deployment-url.com
```

## 🔧 Pre-Deployment Setup

### **Required Environment Variables**
```bash
# Required for API calls
FRONTEND_URL=https://your-chatwoot-deployment.com

# Optional - Twilio SMS Integration
TWILIO_ACCOUNT_SID=your_twilio_account_sid
TWILIO_AUTH_TOKEN=your_twilio_auth_token  
TWILIO_PHONE_NUMBER=your_twilio_phone_number
```

### **Prerequisites**
1. ✅ Chatwoot application deployed and running
2. ✅ Database migrations completed  
3. ✅ APIs accessible and responding
4. ✅ Rails environment properly configured

## 📋 Step-by-Step Process

### **Step 1: Platform App Creation**
- Creates/finds `VoiceLinkAI Platform App`
- Generates platform token for API access
- **API Used:** Direct Rails model (`PlatformApp`)

### **Step 2: Account Creation**
- Creates `voicelinkai` account via Platform API
- Sets locale to `en` and description
- **API Used:** `POST /platform/api/v1/accounts`

### **Step 3: Super Admin Setup**
- Creates user via Platform API
- Adds to account as `administrator` role
- Creates `SuperAdmin` record for system privileges  
- Generates access token for authentication
- **APIs Used:** 
  - `POST /platform/api/v1/users`
  - `POST /platform/api/v1/accounts/{id}/account_users`
  - Direct Rails models (`SuperAdmin`, `AccessToken`)

### **Step 4: Store Admin Setup**
- Creates second user via Platform API
- Adds to account as `administrator` role
- Generates access token for authentication
- **APIs Used:** Same as Step 3 (minus SuperAdmin record)

### **Step 5: Twilio Inbox (Optional)**
- Creates Twilio SMS channel if credentials available
- Configures webhook endpoints automatically
- **API Used:** `POST /api/v1/accounts/{id}/channels/twilio_channel`

### **Step 6: Environment File Generation**
- Creates timestamped `.env` file with all tokens
- Includes deployment notes and next steps
- **File:** `voicelinkai_deployment_tokens_{timestamp}.env`

## 🔐 Generated Credentials

### **Login Accounts**
```
Super Admin:
  Email: admin@voicelinkai.com
  Password: 123@321Qq
  
Store Admin:
  Email: storeadmin@voicelinkai.com  
  Password: 123@321Qq
```

### **Environment Variables for Deployment**
```bash
# Use these in your deployment configuration
CHATWOOT_ADMIN_TOKEN="[super_admin_token]"
CHATWOOT_ADMIN_USER_ID=[super_admin_user_id]
CHATWOOT_PLATFORM_TOKEN="[platform_token]"
CHATWOOT_ACCOUNT_ID=[account_id]
```

## 🧪 Testing & Validation

### **Verify Platform API Access**
```bash
curl -X GET "https://your-deployment.com/platform/api/v1/accounts" \
  -H "api_access_token: [platform_token]"
```

### **Verify Admin API Access**
```bash
curl -X GET "https://your-deployment.com/api/v1/accounts/[account_id]/conversations" \
  -H "api_access_token: [super_admin_token]"
```

### **Test WebSocket Connection**
```bash
# Update your WebSocket tests with new tokens
bundle exec ruby scripts/comprehensive_websocket_multi_user_test.rb
```

## 🚨 Security Considerations

### **Token Management**
- ✅ Store tokens securely in your deployment secrets
- ✅ Use environment variables, never hardcode in source
- ✅ Rotate tokens periodically for production environments
- ✅ Monitor token usage and access patterns

### **Access Control**
- ✅ Super Admin has system-wide access - restrict carefully
- ✅ Store Admin limited to account operations
- ✅ Both can manage the Twilio inbox and all conversations
- ✅ Passwords should be changed after first login

## 🔄 CI/CD Integration

### **GitHub Actions Workflow**
```yaml
- name: Run VoiceLinkAI Seeder
  run: |
    bundle exec rails runner scripts/deployment_seeder_rails.rb ${{ secrets.FRONTEND_URL }}
  env:
    FRONTEND_URL: ${{ secrets.FRONTEND_URL }}
    TWILIO_ACCOUNT_SID: ${{ secrets.TWILIO_ACCOUNT_SID }}
    TWILIO_AUTH_TOKEN: ${{ secrets.TWILIO_AUTH_TOKEN }}
    TWILIO_PHONE_NUMBER: ${{ secrets.TWILIO_PHONE_NUMBER }}
```

### **Container Deployment**
```bash
# Run during container startup after database migrations
bundle exec rails db:migrate
bundle exec rails runner scripts/deployment_seeder_rails.rb
```

## 🛠️ Troubleshooting

### **Common Issues**

**❌ "API Error 401: Unauthorized"**
- Check that the application is fully started
- Verify database migrations are complete
- Ensure platform token generation succeeded

**❌ "Twilio inbox creation failed"**
- Verify TWILIO_* environment variables are set correctly
- Check Twilio account credentials and permissions
- Ensure phone number is in correct format (+1234567890)

**❌ "JSON Parse Error"**
- Application may not be fully ready - wait and retry
- Check application logs for startup issues
- Verify the URL is accessible and returning JSON

### **Recovery Actions**
```bash
# Check if account was created
bundle exec rails runner "puts Account.find_by(name: 'voicelinkai')&.id || 'Not found'"

# Check if users exist
bundle exec rails runner "puts User.where(email: ['admin@voicelinkai.com', 'storeadmin@voicelinkai.com']).pluck(:email, :id)"

# Regenerate tokens if needed
bundle exec rails runner "user = User.find_by(email: 'admin@voicelinkai.com'); puts AccessToken.create!(owner: user, token: SecureRandom.hex(32)).token"
```

## 📊 Monitoring & Maintenance

### **Post-Deployment Checks**
1. ✅ Verify account creation and user access
2. ✅ Test API authentication with generated tokens  
3. ✅ Confirm Twilio integration (if configured)
4. ✅ Validate WebSocket connections work
5. ✅ Update environment configuration with tokens

### **Ongoing Maintenance**
- 🔄 Monitor token usage and expiration
- 🔄 Update passwords after initial setup
- 🔄 Review and rotate credentials periodically
- 🔄 Keep environment tokens synchronized with generation

## 🎯 Success Indicators

When seeder completes successfully, you should have:

- ✅ **Platform Token:** For system-level operations
- ✅ **VoiceLinkAI Account:** Dedicated account space  
- ✅ **Two Admin Users:** Super Admin + Store Admin
- ✅ **Access Tokens:** For API authentication
- ✅ **Environment File:** Ready for deployment configuration
- ✅ **Twilio Inbox:** SMS channel ready (if configured)

**🎉 The Super Admin token becomes your primary `CHATWOOT_ADMIN_TOKEN` for environment variables!**

---

**📞 Support:** For issues with this seeder, check the generated debug files in `./debug/` or create a new debug file following the established patterns. 