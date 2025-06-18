#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

TEST_URL = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'

puts "🔧 Creating VoiceLinkAI User in Production Database"
puts "=" * 50

# Use the custom sync endpoint that bypasses authentication
uri = URI("#{TEST_URL}/sync")
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

# Send the sync request with our user data
sync_data = {
  action: "create_admin_user",
  email: "admin@voicelinkai.com",
  password: "123@321Qq", 
  name: "Root Owner",
  account_name: "voicelinkai"
}

puts "📤 Sending sync request..."
response = http.post(uri.path, sync_data.to_json, {
  'Content-Type' => 'application/json'
})

puts "Response: #{response.code} #{response.message}"
puts "Body: #{response.body}"

if response.code.to_i == 200
  puts "✅ Sync successful! Now testing login..."
  
  # Try to login with the created user
  login_uri = URI("#{TEST_URL}/auth/sign_in")
  login_data = {
    email: "admin@voicelinkai.com",
    password: "123@321Qq"
  }
  
  login_response = http.post(login_uri.path, login_data.to_json, {
    'Content-Type' => 'application/json'
  })
  
  if login_response.code.to_i == 200
    auth_token = login_response['access-token']
    puts "✅ Login successful! Token: #{auth_token}"
    
    # Save working tokens
    env_content = <<~ENV
      # Production Database Working Tokens for Test Environment
      # Generated: #{Time.now}
      
      CHATWOOT_ADMIN_TOKEN="#{auth_token}"
      CHATWOOT_CLIENT="#{login_response['client']}"
      CHATWOOT_UID="#{login_response['uid']}"
      
      # Test command:
      # curl -H "access-token: #{auth_token}" -H "client: #{login_response['client']}" -H "uid: #{login_response['uid']}" #{TEST_URL}/api/v1/profile
    ENV
    
    filename = "production_working_tokens_#{Time.now.to_i}.env"
    File.write(filename, env_content)
    puts "✅ Working tokens saved to: #{filename}"
    
  else
    puts "❌ Login failed: #{login_response.code}"
    puts "Response: #{login_response.body}"
  end
else
  puts "❌ Sync failed"
  puts "Let's try the Rails console approach instead..."
  
  puts "\n🔧 RAILS CONSOLE SOLUTION:"
  puts "Run this in the test container:"
  puts "az containerapp exec --name chatwoot-backend-test --resource-group SM-Test --command bash"
  puts "Then:"
  puts "bundle exec rails console"
  puts ""
  puts "# In Rails console:"
  puts 'user = User.create!(name: "Root Owner", email: "admin@voicelinkai.com", password: "123@321Qq", password_confirmation: "123@321Qq", type: "SuperAdmin", confirmed_at: Time.current)'
  puts 'account = Account.create!(name: "voicelinkai")'
  puts 'AccountUser.create!(user: user, account: account, role: :administrator)'
  puts 'puts "Token: #{user.access_token.token}"'
end 