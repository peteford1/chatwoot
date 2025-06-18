#!/usr/bin/env ruby

# Simple token generation using the API approach
require 'net/http'
require 'json'
require 'uri'

TEST_URL = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
ADMIN_EMAIL = 'admin@voicelinkai.com'
ADMIN_PASSWORD = '123@321Qq'

puts "🔑 Creating tokens for test environment"
puts "URL: #{TEST_URL}"
puts "=" * 50

# Step 1: Try to sign in to get existing token
uri = URI("#{TEST_URL}/auth/sign_in")
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

login_data = {
  email: ADMIN_EMAIL,
  password: ADMIN_PASSWORD
}

puts "🔐 Attempting to sign in with existing user..."
response = http.post(uri.path, login_data.to_json, {'Content-Type' => 'application/json'})

if response.code.to_i == 200
  # Extract token from response headers
  auth_token = response['access-token']
  client = response['client']
  uid = response['uid']
  
  if auth_token
    puts "✅ Successfully logged in!"
    puts "✅ Token: #{auth_token}"
    puts "✅ Client: #{client}" 
    puts "✅ UID: #{uid}"
    
    # Test the token
    test_uri = URI("#{TEST_URL}/api/v1/profile")
    test_response = http.get(test_uri.path, {
      'access-token' => auth_token,
      'client' => client,
      'uid' => uid
    })
    
    if test_response.code.to_i == 200
      profile = JSON.parse(test_response.body)
      puts "✅ Token works! User: #{profile['name']} (#{profile['email']})"
      
      # Generate env file
      env_content = <<~ENV
        # Test Environment Working Tokens
        # Generated: #{Time.now}
        # These tokens work with the test environment
        
        CHATWOOT_ADMIN_TOKEN="#{auth_token}"
        CHATWOOT_CLIENT="#{client}"
        CHATWOOT_UID="#{uid}"
        ADMIN_EMAIL="#{ADMIN_EMAIL}"
        ADMIN_PASSWORD="#{ADMIN_PASSWORD}"
        
        # Test command:
        # curl -H "access-token: #{auth_token}" -H "client: #{client}" -H "uid: #{uid}" #{TEST_URL}/api/v1/profile
      ENV
      
      filename = "test_working_tokens_#{Time.now.to_i}.env"
      File.write(filename, env_content)
      puts "✅ Tokens saved to: #{filename}"
    else
      puts "❌ Token doesn't work for API calls: #{test_response.code} #{test_response.body}"
    end
  else
    puts "❌ No token in response headers"
    puts "Response: #{response.body}"
  end
else
  puts "❌ Login failed: #{response.code}"
  puts "Response: #{response.body}"
  puts ""
  puts "💡 User may not exist in production database"
  puts "💡 Need to create user via onboarding or platform API"
end 