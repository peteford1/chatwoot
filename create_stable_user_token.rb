#!/usr/bin/env ruby

# Rails runner script to create a stable User access token
# Run with: bundle exec rails runner create_stable_user_token.rb

puts "🔍 CHECKING EXISTING USER TOKENS..."
puts "=" * 60

# Find admin users with access tokens
admin_users = User.joins(:access_token).where(type: ['SuperAdmin', 'User']).includes(:access_token, :accounts)

if admin_users.any?
  puts "📋 Found #{admin_users.count} user(s) with access tokens:"
  admin_users.each do |user|
    puts "   ID: #{user.id}"
    puts "   Name: #{user.name}"
    puts "   Email: #{user.email}"
    puts "   Type: #{user.type}"
    puts "   Token: #{user.access_token.token}"
    puts "   Accounts: #{user.accounts.pluck(:name).join(', ')}"
    puts "   Created: #{user.access_token.created_at}"
    puts "   " + "-" * 40
  end
  
  # Test the first admin user's token
  test_user = admin_users.first
  test_token = test_user.access_token.token
  puts "\n🧪 Testing user token: #{test_token}"
  
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
      puts "✅ User token WORKS! No need to create new one."
      puts "🔑 STABLE USER TOKEN: #{test_token}"
      puts "=" * 60
      puts "\n📝 This token:"
      puts "   • Does NOT expire"
      puts "   • Has user-level permissions"
      puts "   • Can access regular API endpoints"
      puts "   • Belongs to: #{test_user.name} (#{test_user.email})"
      puts "\n🧪 Test with:"
      puts "curl -H 'api_access_token: #{test_token}' \\"
      puts "     'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/profile'"
      exit 0
    else
      puts "❌ User token failed: #{response.code} - #{response.message}"
      puts "   Response: #{response.body[0..200]}"
    end
  rescue => e
    puts "❌ Token test error: #{e.message}"
  end
else
  puts "❌ No users with access tokens found"
end

puts "\n🔧 CREATING NEW STABLE USER TOKEN..."
puts "=" * 60

begin
  # Find or create an admin user
  admin_email = "stable-api-admin@voicelinkai.com"
  admin_user = User.find_by(email: admin_email)
  
  if admin_user.nil?
    puts "Creating new admin user: #{admin_email}"
    
    # Find the first account to associate with
    account = Account.first
    if account.nil?
      puts "❌ No accounts found to associate user with"
      exit 1
    end
    
    admin_user = User.create!(
      name: "Stable API Admin",
      email: admin_email,
      password: SecureRandom.hex(16),
      confirmed_at: Time.current,
      type: 'SuperAdmin'
    )
    
    # Associate with account
    AccountUser.create!(
      account: account,
      user: admin_user,
      role: 'administrator'
    )
    
    puts "✅ Admin user created:"
    puts "   ID: #{admin_user.id}"
    puts "   Name: #{admin_user.name}"
    puts "   Email: #{admin_user.email}"
    puts "   Type: #{admin_user.type}"
  else
    puts "✅ Found existing admin user:"
    puts "   ID: #{admin_user.id}"
    puts "   Name: #{admin_user.name}"
    puts "   Email: #{admin_user.email}"
    puts "   Type: #{admin_user.type}"
  end
  
  # Access token is automatically created via AccessTokenable concern
  access_token = admin_user.access_token
  
  if access_token.nil?
    puts "Creating access token..."
    access_token = admin_user.create_access_token
  end
  
  puts "✅ Access Token ready:"
  puts "   Token ID: #{access_token.id}"
  puts "   Token: #{access_token.token}"
  
  puts "\n" + "=" * 60
  puts "🎉 STABLE USER TOKEN READY!"
  puts "=" * 60
  puts "Token: #{access_token.token}"
  puts "=" * 60
  puts "\n📝 This token:"
  puts "   • Does NOT expire"
  puts "   • Has admin-level permissions"
  puts "   • Can access regular API endpoints"
  puts "   • Belongs to: #{admin_user.name} (#{admin_user.email})"
  puts "   • Works with all /api/v1/ endpoints"
  puts "\n🧪 Test with:"
  puts "curl -H 'api_access_token: #{access_token.token}' \\"
  puts "     'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/profile'"
  
  # Test the new token immediately
  puts "\n🧪 Testing new user token..."
  require 'net/http'
  require 'json'
  require 'uri'
  
  begin
    uri = URI("https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/profile")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 10
    request = Net::HTTP::Get.new(uri)
    request['api_access_token'] = access_token.token
    
    response = http.request(request)
    
    if response.code.to_i < 400
      puts "✅ NEW USER TOKEN WORKS PERFECTLY!"
      data = JSON.parse(response.body) rescue nil
      if data && data['email']
        puts "   Profile: #{data['name']} (#{data['email']})"
      end
    else
      puts "❌ New token test failed: #{response.code} - #{response.message}"
      puts "   Response: #{response.body[0..200]}"
    end
  rescue => e
    puts "❌ New token test error: #{e.message}"
  end
  
rescue => e
  puts "❌ Error creating user token: #{e.message}"
  puts "   #{e.backtrace.first}"
end 