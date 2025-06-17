# VoiceLinkAI Fork Deployment Guide (No GitHub Actions)

This guide helps you deploy the VoiceLinkAI seeder to your test environment using your own fork, without relying on GitHub Actions.

## 🚀 Quick Setup Steps

### 1. Create Your Fork
1. Go to https://github.com/chatwoot/chatwoot
2. Click "Fork" button (top right)
3. Create the fork in your GitHub account

### 2. Add Fork as Remote
```bash
# Replace YOUR_USERNAME with your GitHub username
git remote add fork https://github.com/YOUR_USERNAME/chatwoot.git

# Verify remotes
git remote -v
```

### 3. Run Deployment Setup
```bash
chmod +x deploy_to_fork.sh
./deploy_to_fork.sh
```

## 📋 Manual Execution Options

Since we're not using GitHub Actions, you'll execute the seeder manually in your test container:

### Option A: Azure Portal Console (Recommended)
1. **Open Azure Portal**
   - Go to https://portal.azure.com
   - Navigate to Container Apps → chatwoot-backend-test

2. **Access Console**
   - Click on "Console" tab
   - Wait for terminal to load

3. **Execute Full Seeder**
   ```bash
   cd /app
   bundle exec rails runner scripts/deploy_test_env_seeder.rb
   ```

### Option B: Simple Rails Console
1. **Access Rails Console**
   ```bash
   cd /app
   bundle exec rails console
   ```

2. **Copy and paste this code:**
   ```ruby
   puts "=== VoiceLinkAI Test Environment Seeder ==="
   puts "Environment: #{Rails.env rescue 'Unknown'}"
   puts "Creating Platform App..."

   begin
     platform_app = PlatformApp.create!(name: 'VoiceLinkAI Test Platform')
     puts "Platform App Created: ID #{platform_app.id}"
     puts "Access Token: #{platform_app.access_token.token[0..20]}..."
     
     puts "Creating Account..."
     account = Account.create!(name: 'voicelinkai', locale: 'en')
     puts "Account Created: ID #{account.id}"
     
     puts "Creating Admin User..."
     user = User.create!(
       name: 'VoiceLinkAI Admin',
       email: 'admin@voicelinkai.com',
       password: '123@321Qq',
       confirmed_at: Time.current
     )
     puts "User Created: ID #{user.id}"
     puts "User Token: #{user.access_token.token[0..20]}..."
     
     puts "Linking User to Account..."
     account_user = AccountUser.create!(
       account: account,
       user: user,
       role: 'administrator'
     )
     puts "Account User Created: ID #{account_user.id}"
     
     puts "\n=== SUCCESS ==="
     puts "Platform Token: #{platform_app.access_token.token}"
     puts "Admin Token: #{user.access_token.token}"
     puts "Account ID: #{account.id}"
     puts "User ID: #{user.id}"
     
   rescue => e
     puts "ERROR: #{e.message}"
     puts e.backtrace.first(3)
   end
   ```

## 🎯 Expected Results

When successful, you'll see output like:
```
🎯 SUCCESS: Test environment is ready for VoiceLinkAI integration!

📋 Integration Details:
CHATWOOT_URL: https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io
ACCOUNT_ID: [generated_id]
PLATFORM_TOKEN: [your_platform_token]
ADMIN_TOKEN: [your_admin_token]

🔐 Security: All tokens are test-environment specific with schema isolation
```

## 🔧 Troubleshooting

### If Platform App Already Exists
The seeder handles duplicates gracefully and will use existing resources.

### If You Get Permission Errors
Make sure you're in the test environment (Rails.env should be 'test').

### If Database Connection Issues
Check that your container is running and properly configured.

## 📁 Files Included

- `scripts/deploy_test_env_seeder.rb` - Full production seeder with API calls
- `simple_seeder.rb` - Simplified version for manual console execution
- `deploy_to_fork.sh` - Setup script for fork deployment

## 🔐 Security Notes

- All operations use API calls (no direct database access)
- Test environment schema isolation maintained
- Tokens are environment-specific
- Follows Chatwoot Platform API best practices

## ✅ Next Steps

1. Save the generated tokens from the seeder output
2. Use them to configure your VoiceLinkAI integration
3. Test the integration with the test environment

The seeder creates everything needed for VoiceLinkAI to integrate with your Chatwoot test environment! 