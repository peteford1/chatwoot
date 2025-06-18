#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'uri'

# VoiceLinkAI Test Environment API Seeder
# This script creates platform app and then uses API calls within the same environment

puts "🚀 VoiceLinkAI Test Environment API Seeder"
puts "=" * 60

# STEP 1: Create Platform App (requires Rails/database access)
puts "\n🔧 Step 1: Creating Platform App in Test Environment"

platform_app = PlatformApp.create!(name: 'VoiceLinkAI Test Platform')
platform_token = platform_app.access_token.token

puts "✅ Platform App created: #{platform_app.name}"
puts "✅ Platform Token: #{platform_token[0..16]}..."

# STEP 2: Use Platform API to create account
puts "\n🏢 Step 2: Creating Account via Platform API"

def make_api_call(method, endpoint, data = nil, token)
  base_url = ENV['CHATWOOT_URL'] || 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
  uri = URI("#{base_url}#{endpoint}")
  
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == 'https'
  
  case method.upcase
  when 'POST'
    request = Net::HTTP::Post.new(uri.path)
    request.body = data.to_json if data
    request['Content-Type'] = 'application/json'
  when 'GET'
    request = Net::HTTP::Get.new(uri.path)
  end
  
  request['api_access_token'] = token
  
  begin
    response = http.request(request)
    puts "   API Response: #{response.code} - #{response.message}"
    
    if response.code.to_i.between?(200, 299)
      JSON.parse(response.body) rescue response.body
    else
      puts "   Error Body: #{response.body}"
      { error: response.body, status: response.code }
    end
  rescue => e
    puts "   Network Error: #{e.message}"
    { error: e.message }
  end
end

# Create account
account_data = {
  name: 'voicelinkai',
  locale: 'en'
}

account_response = make_api_call('POST', '/platform/api/v1/accounts', account_data, platform_token)

if account_response.is_a?(Hash) && account_response['id']
  account_id = account_response['id']
  puts "✅ Account created: ID #{account_id}"
else
  puts "❌ Account creation failed: #{account_response}"
  exit 1
end

# STEP 3: Create users via Platform API
puts "\n👥 Step 3: Creating Users via Platform API"

# Create admin user
admin_data = {
  name: 'Root Owner',
  email: 'admin@voicelinkai.com',
  password: '123@321Qq'
}

admin_response = make_api_call('POST', '/platform/api/v1/users', admin_data, platform_token)

if admin_response.is_a?(Hash) && admin_response['id']
  admin_user_id = admin_response['id']
  admin_token = admin_response['access_token']
  puts "✅ Admin user created: ID #{admin_user_id}"
  puts "✅ Admin token: #{admin_token[0..16]}..."
else
  puts "❌ Admin user creation failed: #{admin_response}"
  exit 1
end

# STEP 4: Add user to account
puts "\n🔗 Step 4: Adding User to Account"

account_user_data = {
  user_id: admin_user_id,
  role: 'administrator'
}

account_user_response = make_api_call('POST', "/platform/api/v1/accounts/#{account_id}/account_users", account_user_data, platform_token)

if account_user_response.is_a?(Hash) && !account_user_response.key?('error')
  puts "✅ User added to account as administrator"
else
  puts "❌ Account user creation failed: #{account_user_response}"
end

# STEP 5: Output results
puts "\n🎉 Test Environment Setup Complete!"
puts "=" * 60
puts "Platform Token: #{platform_token}"
puts "Account ID: #{account_id}"
puts "Admin User ID: #{admin_user_id}"
puts "Admin Token: #{admin_token}"
puts "=" * 60

# Test the tokens
puts "\n🧪 Testing API Access..."

# Test platform API
platform_test = make_api_call('GET', "/platform/api/v1/accounts/#{account_id}", nil, platform_token)
puts "Platform API Test: #{platform_test.is_a?(Hash) && platform_test['id'] ? '✅ Working' : '❌ Failed'}"

# Test user API  
user_test = make_api_call('GET', '/api/v1/profile', nil, admin_token)
puts "User API Test: #{user_test.is_a?(Hash) && user_test['id'] ? '✅ Working' : '❌ Failed'}"

puts "\n✨ All done! Use the tokens above for API access." 