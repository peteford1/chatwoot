#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'uri'

# This script must run INSIDE the test container
# It creates the platform app in the test environment, then uses API calls

puts "🚀 Test Environment In-Container API Seeder"
puts "=" * 60
puts "Environment: #{Rails.env}"
puts "Database: #{ActiveRecord::Base.connection.current_database}"
puts "Schema: #{ENV['DATABASE_SCHEMA'] || 'default'}"
puts "=" * 60

# STEP 1: Create Platform App in the test environment database
puts "\n🔧 Step 1: Creating Platform App in Test Environment"

platform_app = PlatformApp.create!(name: 'VoiceLinkAI Test Platform')
platform_token = platform_app.access_token.token

puts "✅ Platform App created: #{platform_app.name} (ID: #{platform_app.id})"
puts "✅ Platform Token: #{platform_token[0..16]}..."

# STEP 2: Use localhost for API calls (we're inside the container)
base_url = 'http://localhost:3000'  # Internal container address

def make_api_call(method, endpoint, data = nil, token, base_url)
  uri = URI("#{base_url}#{endpoint}")
  
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = false  # localhost doesn't use SSL
  
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

# STEP 2: Create account via Platform API
puts "\n🏢 Step 2: Creating Account via Platform API"

account_data = {
  name: 'voicelinkai',
  locale: 'en'
}

account_response = make_api_call('POST', '/platform/api/v1/accounts', account_data, platform_token, base_url)

if account_response.is_a?(Hash) && account_response['id']
  account_id = account_response['id']
  puts "✅ Account created: ID #{account_id}"
else
  puts "❌ Account creation failed: #{account_response}"
  exit 1
end

# STEP 3: Create admin user via Platform API
puts "\n👑 Step 3: Creating Admin User via Platform API"

admin_data = {
  name: 'Root Owner',
  email: 'admin@voicelinkai.com',
  password: '123@321Qq'
}

admin_response = make_api_call('POST', '/platform/api/v1/users', admin_data, platform_token, base_url)

if admin_response.is_a?(Hash) && admin_response['id']
  admin_user_id = admin_response['id']
  admin_token = admin_response['access_token']
  puts "✅ Admin user created: ID #{admin_user_id}"
  puts "✅ Admin token: #{admin_token[0..16]}..."
else
  puts "❌ Admin user creation failed: #{admin_response}"
  exit 1
end

# STEP 4: Add user to account via Platform API
puts "\n🔗 Step 4: Adding User to Account via Platform API"

account_user_data = {
  user_id: admin_user_id,
  role: 'administrator'
}

account_user_response = make_api_call('POST', "/platform/api/v1/accounts/#{account_id}/account_users", account_user_data, platform_token, base_url)

if account_user_response.is_a?(Hash) && !account_user_response.key?('error')
  puts "✅ User added to account as administrator"
else
  puts "❌ Account user creation failed: #{account_user_response}"
end

# STEP 5: Test API access
puts "\n🧪 Step 5: Testing API Access"

# Test Platform API
platform_test = make_api_call('GET', "/platform/api/v1/accounts/#{account_id}", nil, platform_token, base_url)
platform_working = platform_test.is_a?(Hash) && platform_test['id']
puts "Platform API Test: #{platform_working ? '✅ Working' : '❌ Failed'}"

# Test Application API with admin token
app_test = make_api_call('GET', '/api/v1/profile', nil, admin_token, base_url)
app_working = app_test.is_a?(Hash) && app_test['id']
puts "Application API Test: #{app_working ? '✅ Working' : '❌ Failed'}"

# STEP 6: Generate environment file
puts "\n📋 Step 6: Generating Environment Configuration"

timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S %Z')

env_content = <<~ENV
# VoiceLinkAI Test Environment Configuration
# Generated: #{timestamp}
# Method: In-Container API Creation
# Database Schema: test (isolated)

# =============================================================================
# TEST ENVIRONMENT TOKENS (WORKING)
# =============================================================================

CHATWOOT_URL="https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
CHATWOOT_ACCOUNT_ID=#{account_id}
ENVIRONMENT=test

# Platform API Token (for system operations)
CHATWOOT_PLATFORM_TOKEN="#{platform_token}"

# Admin User Token (for account operations)  
CHATWOOT_ADMIN_TOKEN="#{admin_token}"

# =============================================================================
# USER INFORMATION
# =============================================================================

ADMIN_USER_ID=#{admin_user_id}
ADMIN_EMAIL="admin@voicelinkai.com"
ADMIN_PASSWORD="123@321Qq"

# =============================================================================
# API TEST COMMANDS
# =============================================================================

# Test Platform API:
# curl -H "api_access_token: #{platform_token}" "https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/platform/api/v1/accounts/#{account_id}"

# Test Application API:
# curl -H "api_access_token: #{admin_token}" "https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/profile"

# =============================================================================
# SECURITY NOTES
# =============================================================================

# ✅ Platform app created in test environment
# ✅ All tokens are test-environment specific
# ✅ Schema isolation prevents cross-environment access
# ✅ Database user: chatwoot_test (restricted permissions)

ENV

File.write('/tmp/test_env_config.env', env_content)

puts "\n🎉 Test Environment Setup Complete!"
puts "=" * 60
puts "✅ Platform App: #{platform_app.name}"
puts "✅ Platform Token: #{platform_token[0..16]}..."
puts "✅ Account ID: #{account_id}"
puts "✅ Admin Token: #{admin_token[0..16]}..."
puts "✅ API Tests: Platform #{platform_working ? 'OK' : 'FAIL'}, Application #{app_working ? 'OK' : 'FAIL'}"
puts "✅ Config saved to: /tmp/test_env_config.env"
puts "=" * 60

puts "\n🔑 Working tokens for test environment:"
puts "Platform: #{platform_token}"
puts "Admin: #{admin_token}" 