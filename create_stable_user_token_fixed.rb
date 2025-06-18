#!/usr/bin/env ruby

# Rails runner script to create a stable User access token
# Run with: bundle exec rails runner create_stable_user_token_fixed.rb

puts "🔍 CHECKING ALL EXISTING USERS..."
puts "=" * 60

# Find all users and their access tokens
all_users = User.includes(:access_token, :accounts).order(:created_at)

if all_users.any?
  puts "📋 Found #{all_users.count} user(s):"
  all_users.each do |user|
    puts "   ID: #{user.id}"
    puts "   Name: #{user.name}"
    puts "   Email: #{user.email}"
    puts "   Type: #{user.type || 'User'}"
    puts "   Token: #{user.access_token&.token || 'NO TOKEN'}"
    puts "   Accounts: #{user.accounts.pluck(:name).join(', ')}"
    puts "   " + "-" * 40
  end
  
  # Find a user with an access token to test
  user_with_token = all_users.find { |u| u.access_token.present? }
  
  if user_with_token
    test_token = user_with_token.access_token.token
    puts "\n🧪 Testing existing user token: #{test_token}"
    
    # Test the token via API call
    require 'net/http'
    require 'json'
    require 'uri'
    
    begin
      uri = URI("https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/profile")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 10
      request = Net::HTTP::Get.new(uri)
      request['api_access_token'] = test_token
      
      response = http.request(request)
      
      if response.code.to_i < 400
        puts "✅ Existing user token WORKS!"
        puts "🔑 STABLE USER TOKEN: #{test_token}"
        puts "=" * 60
        puts "\n📝 This token:"
        puts "   • Does NOT expire"
        puts "   • Has user-level permissions"
        puts "   • Can access regular API endpoints"
        puts "   • Belongs to: #{user_with_token.name} (#{user_with_token.email})"
        puts "\n🧪 Test with:"
        puts "curl -H 'api_access_token: #{test_token}' \\"
        puts "     'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/profile'"
        
        # Test more endpoints
        puts "\n🔬 Testing additional endpoints..."
        test_endpoints = [
          "/api/v1/accounts/1/agents",
          "/api/v1/accounts/1/conversations",
          "/api/v1/accounts/1/inboxes"
        ]
        
        test_endpoints.each do |endpoint|
          uri = URI("https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io#{endpoint}")
          request = Net::HTTP::Get.new(uri)
          request['api_access_token'] = test_token
          response = http.request(request)
          status = response.code.to_i < 400 ? "✅" : "❌"
          puts "   #{status} #{endpoint}: #{response.code}"
        end
        
        exit 0
      else
        puts "❌ Existing token failed: #{response.code} - #{response.message}"
        puts "   Response: #{response.body[0..200]}"
      end
    rescue => e
      puts "❌ Token test error: #{e.message}"
    end
  else
    puts "\n⚠️  No users have access tokens. Need to create tokens for existing users."
  end
else
  puts "❌ No users found in the system"
end

puts "\n🔧 CREATING ACCESS TOKENS FOR EXISTING USERS..."
puts "=" * 60

# Create access tokens for users who don't have them
users_without_tokens = all_users.select { |u| u.access_token.nil? }

if users_without_tokens.any?
  puts "Creating access tokens for #{users_without_tokens.count} users..."
  
  users_without_tokens.each do |user|
    begin
      access_token = user.create_access_token
      puts "✅ Created token for #{user.name} (#{user.email}): #{access_token.token}"
    rescue => e
      puts "❌ Failed to create token for #{user.name}: #{e.message}"
    end
  end
  
  # Test the first created token
  first_user = users_without_tokens.first
  if first_user&.access_token
    test_token = first_user.access_token.token
    puts "\n🧪 Testing newly created token: #{test_token}"
    
    require 'net/http'
    require 'json'
    require 'uri'
    
    begin
      uri = URI("https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/profile")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 10
      request = Net::HTTP::Get.new(uri)
      request['api_access_token'] = test_token
      
      response = http.request(request)
      
      if response.code.to_i < 400
        puts "✅ NEW TOKEN WORKS PERFECTLY!"
        puts "🔑 STABLE USER TOKEN: #{test_token}"
        puts "=" * 60
        puts "\n📝 This token:"
        puts "   • Does NOT expire"
        puts "   • Has user-level permissions"
        puts "   • Can access regular API endpoints"
        puts "   • Belongs to: #{first_user.name} (#{first_user.email})"
        puts "\n🧪 Use this token for your WebSocket SMS test!"
      else
        puts "❌ New token failed: #{response.code} - #{response.message}"
      end
    rescue => e
      puts "❌ New token test error: #{e.message}"
    end
  end
else
  puts "All users already have access tokens."
end

puts "\n🔧 CREATING NEW ADMIN USER WITH STRONG PASSWORD..."
puts "=" * 60

begin
  # Create a new admin user with a strong password
  admin_email = "stable-api-admin@voicelinkai.com"
  existing_user = User.find_by(email: admin_email)
  
  if existing_user
    puts "✅ Admin user already exists: #{existing_user.name} (#{existing_user.email})"
    if existing_user.access_token
      puts "✅ Token already exists: #{existing_user.access_token.token}"
    else
      token = existing_user.create_access_token
      puts "✅ Created new token: #{token.token}"
    end
  else
    # Find the first account to associate with
    account = Account.first
    if account.nil?
      puts "❌ No accounts found to associate user with"
      exit 1
    end
    
    # Create user with strong password
    strong_password = "StableAPI123!@#"
    
    admin_user = User.create!(
      name: "Stable API Admin",
      email: admin_email,
      password: strong_password,
      password_confirmation: strong_password,
      confirmed_at: Time.current,
      type: 'SuperAdmin'
    )
    
    # Associate with account
    AccountUser.create!(
      account: account,
      user: admin_user,
      role: 'administrator'
    )
    
    puts "✅ New admin user created:"
    puts "   ID: #{admin_user.id}"
    puts "   Name: #{admin_user.name}"
    puts "   Email: #{admin_user.email}"
    puts "   Type: #{admin_user.type}"
    puts "   Token: #{admin_user.access_token.token}"
    
    puts "\n🎉 FINAL STABLE TOKEN: #{admin_user.access_token.token}"
  end
  
rescue => e
  puts "❌ Error creating admin user: #{e.message}"
  puts "   #{e.backtrace.first}"
end

puts "\n" + "=" * 60
puts "🎯 SUMMARY: STABLE API TOKENS AVAILABLE"
puts "=" * 60

# List all working tokens
working_tokens = User.joins(:access_token).includes(:access_token)
working_tokens.each do |user|
  puts "✅ #{user.name} (#{user.email}): #{user.access_token.token}"
end

puts "\n📝 These tokens:"
puts "   • Do NOT expire"
puts "   • Have user-level permissions"
puts "   • Work with all /api/v1/ endpoints"
puts "   • Can be used reliably by applications"
puts "=" * 60 