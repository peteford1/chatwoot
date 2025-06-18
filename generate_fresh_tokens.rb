#!/usr/bin/env ruby

puts "🔑 GENERATING FRESH TOKENS USING AZURE DATABASE"
puts "=" * 60

# Create a Rails script that will be executed in the console
rails_script = <<~RUBY
  puts "🚀 Starting token generation in Rails console..."
  
  # Find or create admin user
  admin_email = "admin@voicelinkai.com"
  admin_name = "VoiceLink Admin"
  
  puts "👤 Finding or creating admin user..."
  
  # Try to find existing user
  admin_user = User.find_by(email: admin_email)
  
  if admin_user
    puts "   ✅ Found existing user: \#{admin_user.name} (\#{admin_user.email})"
  else
    puts "   🔧 Creating new admin user..."
    admin_user = User.create!(
      name: admin_name,
      email: admin_email,
      password: "SuperAdmin!",
      password_confirmation: "SuperAdmin!",
      confirmed_at: Time.current
    )
    puts "   ✅ Created admin user: \#{admin_user.name} (\#{admin_user.email})"
  end
  
  # Ensure user is confirmed
  unless admin_user.confirmed?
    admin_user.update!(confirmed_at: Time.current)
    puts "   ✅ Confirmed user account"
  end
  
  # Find or create account
  puts "🏢 Finding or creating account..."
  
  account = Account.first
  if account
    puts "   ✅ Found existing account: \#{account.name} (ID: \#{account.id})"
  else
    puts "   🔧 Creating new account..."
    account = Account.create!(
      name: "VoiceLink Account",
      status: :active
    )
    puts "   ✅ Created account: \#{account.name} (ID: \#{account.id})"
  end
  
  # Ensure user is member of account with administrator role
  puts "🔗 Checking account membership..."
  
  account_user = AccountUser.find_by(user: admin_user, account: account)
  if account_user
    puts "   ✅ User already member of account (Role: \#{account_user.role})"
    # Ensure user is administrator
    unless account_user.administrator?
      account_user.update!(role: :administrator)
      puts "   ✅ Updated user role to administrator"
    end
  else
    puts "   🔧 Adding user to account as administrator..."
    AccountUser.create!(
      user: admin_user,
      account: account,
      role: :administrator
    )
    puts "   ✅ Added user to account as administrator"
  end
  
  # Set current account context for token generation
  Current.account = account
  
  # Create API access token
  puts "🔑 Creating API access token..."
  
  # Delete existing tokens for this user
  AccessToken.where(owner: admin_user).destroy_all
  
  # Generate new token
  access_token = AccessToken.create!(
    owner: admin_user,
    token: SecureRandom.hex(32)
  )
  
  puts "   ✅ Created API token: \#{access_token.token}"
  
  # Create platform app and token
  puts "🚀 Creating platform app and token..."
  
  # Delete existing platform apps
  PlatformApp.where(name: "VoiceLink Platform App").destroy_all
  
  # Create platform app
  platform_app = PlatformApp.create!(
    name: "VoiceLink Platform App"
  )
  
  puts "   ✅ Created platform app: \#{platform_app.name} (ID: \#{platform_app.id})"
  
  # Create platform app permissible (link to account)
  PlatformAppPermissible.create!(
    platform_app: platform_app,
    permissible: account
  )
  
  puts "   ✅ Linked platform app to account"
  
  # Create access token for platform app
  platform_token = AccessToken.create!(
    owner: platform_app,
    token: SecureRandom.hex(32)
  )
  
  puts "   ✅ Created platform token: \#{platform_token.token}"
  
  # Summary
  puts ""
  puts "=" * 60
  puts "🎯 TOKEN GENERATION COMPLETE"
  puts "=" * 60
  
  puts ""
  puts "👤 Admin User:"
  puts "   ID: \#{admin_user.id}"
  puts "   Name: \#{admin_user.name}"
  puts "   Email: \#{admin_user.email}"
  puts "   Confirmed: \#{admin_user.confirmed? ? '✅' : '❌'}"
  
  puts ""
  puts "🏢 Account:"
  puts "   ID: \#{account.id}"
  puts "   Name: \#{account.name}"
  puts "   Status: \#{account.status}"
  
  puts ""
  puts "👥 Account User:"
  puts "   Role: \#{account_user.role}"
  puts "   Administrator: \#{account_user.administrator? ? '✅' : '❌'}"
  
  puts ""
  puts "🔑 API Access Token (User):"
  puts "   Token: \#{access_token.token}"
  puts "   Owner: User \#{admin_user.id}"
  
  puts ""
  puts "🚀 Platform Token:"
  puts "   Token: \#{platform_token.token}"
  puts "   App: \#{platform_app.name} (ID: \#{platform_app.id})"
  
  puts ""
  puts "📝 Environment Variables:"
  puts "   export CHATWOOT_ADMIN_USER_ID=\#{admin_user.id}"
  puts "   export CHATWOOT_ADMIN_TOKEN=\"\#{access_token.token}\""
  puts "   export CHATWOOT_PLATFORM_TOKEN=\"\#{platform_token.token}\""
  puts "   export CHATWOOT_ACCOUNT_ID=\#{account.id}"
  puts "   export CHATWOOT_ACCOUNT_NAME=\"\#{account.name}\""
  puts "   export CHATWOOT_USER_TOKEN=\"\#{access_token.token}\""
  puts "   export CHATWOOT_USER_ID=\#{admin_user.id}"
  puts "   export CHATWOOT_USER_EMAIL=\"\#{admin_user.email}\""
  
  # Write to environment file
  puts ""
  puts "💾 Writing to environment file..."
  
  env_content = <<~ENV
    
    # ============================================================================
    # FRESH TOKENS GENERATED FROM AZURE DATABASE - \#{Time.current}
    # ============================================================================
    
    # Admin user and tokens
    export CHATWOOT_ADMIN_USER_ID=\#{admin_user.id}
    export CHATWOOT_ADMIN_TOKEN=\"\#{access_token.token}\"
    export CHATWOOT_PLATFORM_TOKEN=\"\#{platform_token.token}\"
    export CHATWOOT_ACCOUNT_ID=\#{account.id}
    export CHATWOOT_ACCOUNT_NAME=\"\#{account.name}\"
    
    # Set primary token for testing
    export CHATWOOT_USER_TOKEN=\"\#{access_token.token}\"
    export CHATWOOT_USER_ID=\#{admin_user.id}
    export CHATWOOT_USER_EMAIL=\"\#{admin_user.email}\"
    
    # API Base URL
    export CHATWOOT_API_BASE_URL=https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io
  ENV
  
  File.open('fresh_tokens.env', 'w') { |f| f.write(env_content) }
  puts "   ✅ Environment variables written to fresh_tokens.env"
  
  puts ""
  puts "🎯 READY FOR TESTING!"
  puts "   1. Source tokens: source fresh_tokens.env"
  puts "   2. Test tokens: ruby test_provided_tokens.rb"
  puts "   3. Run SMS test: ruby live_websocket_sms_test_auto.rb"
  
  # Return the tokens for verification
  {
    admin_user: admin_user,
    account: account,
    account_user: account_user,
    api_token: access_token.token,
    platform_token: platform_token.token
  }
RUBY

# Write the script to a temporary file
script_file = 'temp_token_generation.rb'
File.write(script_file, rails_script)

puts "\n🔧 Executing Rails script to generate tokens..."
puts "   Script file: #{script_file}"
puts "   Using Azure Database: #{ENV['POSTGRES_HOST']}"

# Execute the script in Rails console
system("rails runner #{script_file}")

# Clean up the temporary script file
File.delete(script_file) if File.exist?(script_file)

puts "\n✅ Token generation script completed!"
puts "\nNext steps:"
puts "1. Check the output above for the generated tokens"
puts "2. Source the environment file: source fresh_tokens.env"
puts "3. Test the tokens with your API" 