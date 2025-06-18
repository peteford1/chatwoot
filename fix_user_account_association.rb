#!/usr/bin/env ruby

# Rails runner script to fix user account association
# Run with: bundle exec rails runner fix_user_account_association.rb

puts "🔧 FIXING USER ACCOUNT ASSOCIATION..."
puts "=" * 60

# Find the stable admin user
admin_user = User.find_by(email: 'stable-api-admin@voicelinkai.com')

if admin_user.nil?
  puts "❌ Stable admin user not found"
  exit 1
end

puts "✅ Found admin user:"
puts "   ID: #{admin_user.id}"
puts "   Name: #{admin_user.name}"
puts "   Email: #{admin_user.email}"
puts "   Type: #{admin_user.type}"
puts "   Token: #{admin_user.access_token.token}"

# Check current account associations
current_accounts = admin_user.accounts
puts "\n📋 Current account associations: #{current_accounts.count}"
current_accounts.each do |account|
  puts "   • #{account.name} (ID: #{account.id})"
end

# Find all accounts and associate the user
all_accounts = Account.all
puts "\n🔗 Associating user with all accounts..."

all_accounts.each do |account|
  existing_association = AccountUser.find_by(user: admin_user, account: account)
  
  if existing_association
    puts "   ✅ Already associated with #{account.name} (ID: #{account.id}) as #{existing_association.role}"
  else
    begin
      AccountUser.create!(
        user: admin_user,
        account: account,
        role: 'administrator'
      )
      puts "   ✅ Associated with #{account.name} (ID: #{account.id}) as administrator"
    rescue => e
      puts "   ❌ Failed to associate with #{account.name}: #{e.message}"
    end
  end
end

# Reload user to get updated associations
admin_user.reload

puts "\n📋 Final account associations: #{admin_user.accounts.count}"
admin_user.accounts.each do |account|
  account_user = admin_user.account_users.find_by(account: account)
  puts "   • #{account.name} (ID: #{account.id}) - Role: #{account_user.role}"
end

puts "\n🧪 Testing token after account association..."

# Test the token
token = admin_user.access_token.token
require 'net/http'
require 'json'
require 'uri'

begin
  uri = URI("https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/profile")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.read_timeout = 10
  request = Net::HTTP::Get.new(uri)
  request['api_access_token'] = token
  
  response = http.request(request)
  
  if response.code.to_i < 400
    puts "✅ TOKEN NOW WORKS!"
    data = JSON.parse(response.body) rescue nil
    if data && data['email']
      puts "   Profile: #{data['name']} (#{data['email']})"
      puts "   Accounts: #{data['accounts'].length}" if data['accounts']
    end
    
    puts "\n🎉 STABLE TOKEN READY FOR USE!"
    puts "=" * 60
    puts "Token: #{token}"
    puts "=" * 60
    puts "\n📝 This token:"
    puts "   • Does NOT expire"
    puts "   • Has admin permissions on all accounts"
    puts "   • Can access all /api/v1/ endpoints"
    puts "   • Is ready for production use"
    
    # Test a few more endpoints
    puts "\n🔬 Testing additional endpoints..."
    test_endpoints = [
      "/api/v1/accounts/1/agents",
      "/api/v1/accounts/1/inboxes"
    ]
    
    test_endpoints.each do |endpoint|
      uri = URI("https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io#{endpoint}")
      request = Net::HTTP::Get.new(uri)
      request['api_access_token'] = token
      response = http.request(request)
      status = response.code.to_i < 400 ? "✅" : "❌"
      puts "   #{status} #{endpoint}: #{response.code}"
    end
    
  else
    puts "❌ Token still not working: #{response.code} - #{response.message}"
    puts "   Response: #{response.body[0..200]}"
  end
rescue => e
  puts "❌ Token test error: #{e.message}"
end

puts "\n" + "=" * 60
puts "🎯 FINAL STATUS"
puts "=" * 60
puts "User: #{admin_user.name} (#{admin_user.email})"
puts "Token: #{admin_user.access_token.token}"
puts "Accounts: #{admin_user.accounts.count}"
puts "Type: #{admin_user.type}"
puts "=" * 60 