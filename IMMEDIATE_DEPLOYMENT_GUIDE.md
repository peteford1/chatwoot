# 🚀 Immediate VoiceLinkAI Seeder Deployment

Since your GitHub fork is still being created, here are **immediate options** to deploy the VoiceLinkAI seeder to your test environment:

## 🎯 Option 1: Direct Azure Portal Execution (Fastest)

### Step 1: Access Azure Portal Console
1. Go to https://portal.azure.com
2. Navigate to **Container Apps** → **chatwoot-backend-test**
3. Click the **"Console"** tab
4. Wait for the terminal to load

### Step 2: Execute Simple Seeder
Copy and paste this entire block into the Azure console:

```bash
cd /app && bundle exec rails console
```

Then in the Rails console, copy and paste this:

```ruby
puts "=== VoiceLinkAI Test Environment Seeder ==="
puts "Environment: #{Rails.env rescue 'Unknown'}"
puts "Creating Platform App..."

begin
  # Check for existing platform app first
  existing_app = PlatformApp.find_by(name: 'VoiceLinkAI Test Platform')
  if existing_app
    puts "⚠️  Platform app already exists, using existing one"
    platform_app = existing_app
  else
    platform_app = PlatformApp.create!(name: 'VoiceLinkAI Test Platform')
    puts "✅ Platform App Created: ID #{platform_app.id}"
  end
  
  puts "Platform Token: #{platform_app.access_token.token[0..20]}..."
  
  # Check for existing account
  existing_account = Account.find_by(name: 'voicelinkai')
  if existing_account
    puts "⚠️  Account already exists, using existing one"
    account = existing_account
  else
    puts "Creating Account..."
    account = Account.create!(name: 'voicelinkai', locale: 'en')
    puts "✅ Account Created: ID #{account.id}"
  end
  
  # Check for existing user
  existing_user = User.find_by(email: 'admin@voicelinkai.com')
  if existing_user
    puts "⚠️  User already exists, using existing one"
    user = existing_user
  else
    puts "Creating Admin User..."
    user = User.create!(
      name: 'VoiceLinkAI Admin',
      email: 'admin@voicelinkai.com',
      password: '123@321Qq',
      confirmed_at: Time.current
    )
    puts "✅ User Created: ID #{user.id}"
  end
  
  puts "User Token: #{user.access_token.token[0..20]}..."
  
  # Check for existing account user link
  existing_link = AccountUser.find_by(account: account, user: user)
  if existing_link
    puts "⚠️  User already linked to account"
  else
    puts "Linking User to Account..."
    account_user = AccountUser.create!(
      account: account,
      user: user,
      role: 'administrator'
    )
    puts "✅ Account User Created: ID #{account_user.id}"
  end
  
  puts "\n🎯 === SUCCESS ==="
  puts "Environment: Test (#{Rails.env})"
  puts "CHATWOOT_URL: https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
  puts "ACCOUNT_ID: #{account.id}"
  puts "PLATFORM_TOKEN: #{platform_app.access_token.token}"
  puts "ADMIN_TOKEN: #{user.access_token.token}"
  puts "USER_ID: #{user.id}"
  puts "\n🔐 All tokens are test-environment specific with schema isolation"
  
rescue => e
  puts "❌ ERROR: #{e.message}"
  puts e.backtrace.first(5)
end
```

## 🎯 Option 2: Wait for Fork and Use Full Seeder

Once your fork at `https://github.com/peteford1/chatwoot` is ready:

### Step 1: Update Git Remote
```bash
git remote add fork https://github.com/peteford1/chatwoot.git
```

### Step 2: Push Seeder Files
```bash
git checkout -b voicelinkai-seeder
git add scripts/deploy_test_env_seeder.rb simple_seeder.rb
git commit -m "Add VoiceLinkAI seeder"
git push fork voicelinkai-seeder
```

### Step 3: Execute Full Seeder in Azure Portal
```bash
cd /app
bundle exec rails runner scripts/deploy_test_env_seeder.rb
```

## 📋 Expected Output

When successful, you'll see:
```
🎯 === SUCCESS ===
Environment: Test (test)
CHATWOOT_URL: https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io
ACCOUNT_ID: [your_account_id]
PLATFORM_TOKEN: [your_platform_token]
ADMIN_TOKEN: [your_admin_token]
USER_ID: [your_user_id]

🔐 All tokens are test-environment specific with schema isolation
```

## ✅ Integration Ready

Save these tokens and use them to configure VoiceLinkAI:
- **CHATWOOT_URL**: Your test environment endpoint
- **ACCOUNT_ID**: The voicelinkai account ID
- **PLATFORM_TOKEN**: For Platform API calls
- **ADMIN_TOKEN**: For Application API calls

## 🔧 Troubleshooting

- **"Platform app already exists"**: Normal, seeder handles duplicates
- **"User already exists"**: Normal, seeder reuses existing resources
- **Permission errors**: Ensure you're in test environment (Rails.env = 'test')
- **Database errors**: Check container is running and healthy

## 🚀 Recommendation

**Use Option 1** for immediate deployment - it's faster and doesn't require waiting for the fork to be ready. The seeder handles duplicates gracefully, so you can run it multiple times safely. 