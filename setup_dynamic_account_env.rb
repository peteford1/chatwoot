#!/usr/bin/env ruby

# Run this script to dynamically set CHATWOOT_ACCOUNT_ID based on admin@voicelinkai.com
# Usage: rails runner setup_dynamic_account_env.rb

puts "🔍 SETTING UP DYNAMIC ACCOUNT ENVIRONMENT"
puts "=" * 50

TARGET_EMAIL = 'stable-api-admin@voicelinkai.com'

puts "\n📧 Looking up user: #{TARGET_EMAIL}"

begin
  # Find the user by email
  user = User.find_by(email: TARGET_EMAIL)
  
  if user
    puts "✅ User found:"
    puts "   ID: #{user.id}"
    puts "   Name: #{user.name}"
    puts "   Email: #{user.email}"
    puts "   Type: #{user.type || 'Regular User'}"
    puts "   Created: #{user.created_at}"
    
    # Check if user has access token
    if user.access_token
      puts "   Token: #{user.access_token.token[0..15]}..."
      user_token = user.access_token.token
    else
      puts "   ❌ No access token found"
      user_token = nil
    end
    
    # Find accounts associated with this user
    puts "\n🏢 Finding associated accounts..."
    
    if user.type == 'SuperAdmin'
      puts "   User is SuperAdmin - has access to all accounts"
      accounts = Account.all
      puts "   Total accounts available: #{accounts.count}"
      
      if accounts.any?
        # Use the first account for SuperAdmin
        account = accounts.first
        puts "   Using first account: #{account.name} (ID: #{account.id})"
      else
        puts "   ❌ No accounts found in system"
        account = nil
      end
      
    else
      # Regular user - find through account_users
      account_users = user.account_users.includes(:account)
      
      if account_users.any?
        puts "   Found #{account_users.count} account association(s):"
        
        account_users.each_with_index do |au, index|
          puts "   #{index + 1}. Account: #{au.account.name} (ID: #{au.account.id})"
          puts "      Role: #{au.role}"
          puts "      Created: #{au.created_at}"
        end
        
        # Use the first account
        account = account_users.first.account
        puts "\n   Using first account: #{account.name} (ID: #{account.id})"
        
      else
        puts "   ❌ No account associations found"
        puts "   This user is not associated with any accounts"
        account = nil
      end
    end
    
    # Set environment variables
    if account
      puts "\n🔧 Setting environment variables..."
      
      account_id = account.id
      
      # Create environment file
      env_content = <<~ENV
        # Chatwoot Dynamic Environment Configuration
        # Generated on #{Time.current}
        # Based on user: #{TARGET_EMAIL}
        
        export CHATWOOT_ACCOUNT_ID=#{account_id}
        export CHATWOOT_ACCOUNT_NAME="#{account.name}"
        export CHATWOOT_USER_ID=#{user.id}
        export CHATWOOT_USER_EMAIL="#{user.email}"
      ENV
      
      if user_token
        env_content += "export CHATWOOT_USER_TOKEN=\"#{user_token}\"\n"
      end
      
      # Write to .env file
      File.write('.env.chatwoot', env_content)
      puts "   ✅ Created .env.chatwoot file"
      
      # Create shell script for easy sourcing
      shell_content = <<~SHELL
        #!/bin/bash
        # Chatwoot Dynamic Environment Setup
        # Source this file: source chatwoot_env.sh
        
        echo "🚀 Loading Chatwoot environment for #{TARGET_EMAIL}..."
        
        export CHATWOOT_ACCOUNT_ID=#{account_id}
        export CHATWOOT_ACCOUNT_NAME="#{account.name}"
        export CHATWOOT_USER_ID=#{user.id}
        export CHATWOOT_USER_EMAIL="#{user.email}"
      SHELL
      
      if user_token
        shell_content += "export CHATWOOT_USER_TOKEN=\"#{user_token}\"\n"
      end
      
      shell_content += <<~SHELL
        
        echo "   Account ID: $CHATWOOT_ACCOUNT_ID"
        echo "   Account Name: $CHATWOOT_ACCOUNT_NAME"
        echo "   User ID: $CHATWOOT_USER_ID"
        echo "   User Email: $CHATWOOT_USER_EMAIL"
      SHELL
      
      if user_token
        shell_content += "echo \"   User Token: ${CHATWOOT_USER_TOKEN:0:15}...\"\n"
      end
      
      shell_content += "echo \"✅ Chatwoot environment loaded!\"\n"
      
      File.write('chatwoot_env.sh', shell_content)
      File.chmod(0755, 'chatwoot_env.sh')
      puts "   ✅ Created chatwoot_env.sh script"
      
      # Create Ruby constant file
      ruby_content = <<~RUBY
        # Chatwoot Dynamic Configuration
        # Generated on #{Time.current}
        # Based on user: #{TARGET_EMAIL}
        
        module ChatwootConfig
          ACCOUNT_ID = #{account_id}
          ACCOUNT_NAME = "#{account.name}"
          USER_ID = #{user.id}
          USER_EMAIL = "#{user.email}"
      RUBY
      
      if user_token
        ruby_content += "  USER_TOKEN = \"#{user_token}\"\n"
      end
      
      ruby_content += "end\n"
      
      File.write('chatwoot_config.rb', ruby_content)
      puts "   ✅ Created chatwoot_config.rb module"
      
      puts "\n📋 ENVIRONMENT SUMMARY:"
      puts "   CHATWOOT_ACCOUNT_ID=#{account_id}"
      puts "   CHATWOOT_ACCOUNT_NAME=\"#{account.name}\""
      puts "   CHATWOOT_USER_ID=#{user.id}"
      puts "   CHATWOOT_USER_EMAIL=\"#{user.email}\""
      if user_token
        puts "   CHATWOOT_USER_TOKEN=\"#{user_token[0..15]}...\""
      end
      
      puts "\n💡 USAGE:"
      puts "   # In shell scripts:"
      puts "   source chatwoot_env.sh"
      puts "   echo $CHATWOOT_ACCOUNT_ID"
      puts ""
      puts "   # In Ruby scripts:"
      puts "   require './chatwoot_config'"
      puts "   account_id = ChatwootConfig::ACCOUNT_ID"
      puts ""
      puts "   # In environment files:"
      puts "   source .env.chatwoot"
      
    else
      puts "\n❌ Cannot set environment - no account found"
    end
    
  else
    puts "❌ User not found: #{TARGET_EMAIL}"
    puts "\n🔍 Available users:"
    
    # Show available users for reference
    users = User.limit(10)
    users.each do |u|
      puts "   • #{u.email} (#{u.name}) - ID: #{u.id}"
    end
  end
  
rescue => e
  puts "❌ Error: #{e.class} - #{e.message}"
  puts e.backtrace.first(3).join("\n")
end

puts "\n" + "=" * 50
puts "Dynamic account environment setup complete."
puts "=" * 50 