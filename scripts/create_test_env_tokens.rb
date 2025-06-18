#!/usr/bin/env ruby

puts "🔑 Creating Tokens for Test Environment"
puts "=" * 50

# This script creates tokens in the production database that the test environment uses

ADMIN_EMAIL = 'admin@voicelinkai.com'
ADMIN_PASSWORD = '123@321Qq'

# Check if user exists
existing_user = User.find_by(email: ADMIN_EMAIL)

if existing_user
  puts "✅ Found existing user: #{existing_user.email} (ID: #{existing_user.id})"
  
  # Check if user has an access token
  if existing_user.access_token
    puts "✅ User already has access token: #{existing_user.access_token.token}"
  else
    # Create access token for existing user
    token = existing_user.create_access_token
    puts "✅ Created new access token: #{token.token}"
  end
  
  admin_user = existing_user
else
  puts "❌ No user found with email #{ADMIN_EMAIL}"
  puts "🔧 Creating new user..."
  
  # Create new user
  admin_user = User.create!(
    name: 'Root Owner',
    email: ADMIN_EMAIL,
    password: ADMIN_PASSWORD,
    password_confirmation: ADMIN_PASSWORD,
    type: 'SuperAdmin',
    confirmed_at: Time.current
  )
  
  puts "✅ Created new SuperAdmin user: #{admin_user.email} (ID: #{admin_user.id})"
end

# Get account
account = Account.first || Account.create!(name: 'voicelinkai')
puts "✅ Using account: #{account.name} (ID: #{account.id})"

# Ensure user is member of account
account_user = AccountUser.find_by(user: admin_user, account: account)
unless account_user
  AccountUser.create!(
    user: admin_user,
    account: account,
    role: :administrator
  )
  puts "✅ Added user to account as administrator"
end

# Create platform app and token
platform_app = PlatformApp.find_by(name: 'VoiceLinkAI Platform App') || 
               PlatformApp.create!(name: 'VoiceLinkAI Platform App')

puts "✅ Platform app: #{platform_app.name} (ID: #{platform_app.id})"

# Output the tokens
puts "\n🎯 WORKING TOKENS FOR TEST ENVIRONMENT:"
puts "=" * 50
puts "# Test Environment Database: chatwoot_production"
puts "# These tokens will work with the current test container"
puts ""
puts "CHATWOOT_ADMIN_TOKEN=\"#{admin_user.access_token.token}\""
puts "CHATWOOT_ADMIN_USER_ID=#{admin_user.id}"
puts "CHATWOOT_PLATFORM_TOKEN=\"#{platform_app.access_token.token}\""
puts "CHATWOOT_ACCOUNT_ID=#{account.id}"
puts ""
puts "# Test command:"
puts "curl -H \"api_access_token: #{admin_user.access_token.token}\" \\"
puts "     https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/profile"

# Save to file
env_content = <<~ENV
  # Test Environment Tokens - Production Database
  # Generated: #{Time.current}
  # These tokens exist in the chatwoot_production database used by test container
  
  CHATWOOT_ADMIN_TOKEN="#{admin_user.access_token.token}"
  CHATWOOT_ADMIN_USER_ID=#{admin_user.id}
  CHATWOOT_PLATFORM_TOKEN="#{platform_app.access_token.token}"
  CHATWOOT_ACCOUNT_ID=#{account.id}
  
  # Login credentials
  ADMIN_EMAIL="#{ADMIN_EMAIL}"
  ADMIN_PASSWORD="#{ADMIN_PASSWORD}"
  
  # Test command
  # curl -H "api_access_token: #{admin_user.access_token.token}" https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/profile
ENV

filename = "test_env_tokens_#{Time.now.to_i}.env"
File.write(filename, env_content)
puts "\n✅ Tokens saved to: #{filename}" 