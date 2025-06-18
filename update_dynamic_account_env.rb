#!/usr/bin/env ruby

# Run this script after connecting to Azure database to populate dynamic account info
# Usage: rails runner update_dynamic_account_env.rb

puts "🔍 UPDATING DYNAMIC ACCOUNT ENVIRONMENT VARIABLES"
puts "=" * 60

# Target email to look up
TARGET_EMAIL = ENV['CHATWOOT_TARGET_EMAIL'] || 'admin@voicelinkai.com'

puts "\n📧 Looking up user: #{TARGET_EMAIL}"
puts "🗄️  Current database: #{ActiveRecord::Base.connection.current_database}"
puts "🌍 Rails environment: #{Rails.env}"

begin
  # Find the user by email
  user = User.find_by(email: TARGET_EMAIL)
  
  if user.nil?
    puts "\n❌ User not found: #{TARGET_EMAIL}"
    puts "\n🔍 Available users in database:"
    
    User.limit(10).each do |u|
      puts "   - #{u.email} (ID: #{u.id}, Type: #{u.type || 'Regular'})"
    end
    
    puts "\n💡 Try setting CHATWOOT_TARGET_EMAIL environment variable to an existing email"
    exit 1
  end
  
  puts "\n✅ User found:"
  puts "   ID: #{user.id}"
  puts "   Name: #{user.name}"
  puts "   Email: #{user.email}"
  puts "   Type: #{user.type || 'Regular User'}"
  puts "   Created: #{user.created_at}"
  
  # Get user's access token
  access_token = user.access_token
  if access_token
    puts "   Token: #{access_token.token[0..15]}...#{access_token.token[-4..-1]}"
  else
    puts "   Token: None (will create one)"
  end
  
  # Find user's account memberships
  account_users = AccountUser.where(user: user)
  
  if account_users.empty?
    puts "\n❌ User has no account memberships"
    exit 1
  end
  
  puts "\n📊 Account Memberships:"
  account_users.each do |au|
    account = au.account
    puts "   - Account ID: #{account.id}"
    puts "     Name: #{account.name}"
    puts "     Role: #{au.role}"
    puts "     Status: #{account.status}"
    puts "     Created: #{account.created_at}"
    puts ""
  end
  
  # Use the first account (or primary account)
  primary_account = account_users.first.account
  
  # Create access token if doesn't exist
  if access_token.nil?
    puts "🔑 Creating access token for user..."
    access_token = user.create_access_token
    puts "   New token created: #{access_token.token[0..15]}...#{access_token.token[-4..-1]}"
  end
  
  puts "\n🎯 SELECTED CONFIGURATION:"
  puts "   Account ID: #{primary_account.id}"
  puts "   Account Name: #{primary_account.name}"
  puts "   User ID: #{user.id}"
  puts "   User Email: #{user.email}"
  puts "   User Token: #{access_token.token}"
  
  # Update the environment configuration file
  config_file = 'azure_database_config.env'
  
  puts "\n📝 Updating #{config_file}..."
  
  # Read current config
  config_content = File.read(config_file)
  
  # Update the dynamic variables section
  updated_content = config_content.gsub(
    /# These will be populated after connecting to the production database.*?# CHATWOOT_USER_TOKEN=/m,
    <<~CONFIG
      # These values were populated on #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}
      export CHATWOOT_ACCOUNT_ID=#{primary_account.id}
      export CHATWOOT_ACCOUNT_NAME=\"#{primary_account.name}\"
      export CHATWOOT_USER_ID=#{user.id}
      export CHATWOOT_USER_EMAIL=#{user.email}
      export CHATWOOT_USER_TOKEN=#{access_token.token}
      
      # Additional account information
      export CHATWOOT_ACCOUNT_STATUS=#{primary_account.status}
      export CHATWOOT_USER_ROLE=#{account_users.first.role}
      
      # ============================================================================
      # SSL AND SECURITY SETTINGS
      # ============================================================================
      
      # Force SSL connections to database
      export POSTGRES_SSLMODE=require
      
      # Rails security settings for production
      export RAILS_SERVE_STATIC_FILES=true
      export RAILS_LOG_TO_STDOUT=true
      
      echo "🚀 Azure Database Configuration Loaded"
      echo "   Database Host: $POSTGRES_HOST"
      echo "   Database Name: $POSTGRES_DATABASE"
      echo "   Rails Environment: $RAILS_ENV"
      echo "   API Base URL: $CHATWOOT_API_BASE_URL"
      echo "   Account: $CHATWOOT_ACCOUNT_NAME (ID: $CHATWOOT_ACCOUNT_ID)"
      echo "   User: $CHATWOOT_USER_EMAIL (ID: $CHATWOOT_USER_ID)"
    CONFIG
  )
  
  # Write updated config
  File.write(config_file, updated_content)
  
  puts "✅ Configuration updated successfully!"
  
  puts "\n🚀 NEXT STEPS:"
  puts "1. Source the updated configuration:"
  puts "   source azure_database_config.env"
  puts ""
  puts "2. Test API authentication:"
  puts "   ruby test_authentication_with_dynamic_env.rb"
  puts ""
  puts "3. Run your SMS WebSocket tests:"
  puts "   ruby live_websocket_sms_test_auto.rb"
  
rescue => e
  puts "\n❌ Error: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  exit 1
end 