#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'uri'

# API-First Example script for creating Twilio SMS inbox for account 22
# Uses Chatwoot's REST API instead of direct database access

puts "🚀 Twilio SMS Inbox Creation - API-First Approach"
puts "=" * 60

# Configuration - Update these values
CHATWOOT_BASE_URL = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
ACCOUNT_ID = 22
ADMIN_ACCESS_TOKEN = 'YOUR_ADMIN_ACCESS_TOKEN_HERE'  # Get from user profile or create new one

# Twilio Configuration - Update these
TWILIO_CONFIG = {
  account_sid: 'AC1234567890abcdef1234567890abcdef',  # Your Twilio Account SID
  auth_token: 'your_twilio_auth_token_here',          # Your Twilio Auth Token
  phone_number: '+19999999999',                       # Your Twilio phone number (E.164 format)
  inbox_name: 'Account 22 Twilio SMS'
}

def make_api_request(method, endpoint, data = nil, token = nil)
  uri = URI("#{CHATWOOT_BASE_URL}#{endpoint}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true if uri.scheme == 'https'
  
  case method.upcase
  when 'GET'
    request = Net::HTTP::Get.new(uri)
  when 'POST'
    request = Net::HTTP::Post.new(uri)
    request.body = data.to_json if data
  when 'PUT'
    request = Net::HTTP::Put.new(uri)
    request.body = data.to_json if data
  end
  
  request['Content-Type'] = 'application/json'
  request['Authorization'] = "Bearer #{token}" if token
  
  response = http.request(request)
  
  {
    status: response.code.to_i,
    body: response.body,
    parsed: (JSON.parse(response.body) rescue response.body)
  }
end

# Method 1: Using Chatwoot Admin API
puts "\n📋 METHOD 1: Chatwoot Admin API (Recommended)"
puts "-" * 50

def create_twilio_inbox_via_api
  puts "🔍 Step 1: Verify account exists..."
  
  # Check if account exists
  account_response = make_api_request('GET', "/api/v1/accounts/#{ACCOUNT_ID}", nil, ADMIN_ACCESS_TOKEN)
  
  if account_response[:status] != 200
    puts "❌ Account #{ACCOUNT_ID} not found or access denied"
    puts "   Response: #{account_response[:parsed]}"
    return false
  end
  
  account_name = account_response[:parsed]['name']
  puts "✅ Account found: #{account_name}"
  
  puts "\n📱 Step 2: Creating Twilio SMS inbox..."
  
  # Create inbox with Twilio SMS channel
  inbox_data = {
    name: TWILIO_CONFIG[:inbox_name],
    channel: {
      type: 'sms',
      phone_number: TWILIO_CONFIG[:phone_number],
      provider_config: {
        account_sid: TWILIO_CONFIG[:account_sid],
        auth_token: TWILIO_CONFIG[:auth_token],
        provider: 'twilio'
      }
    },
    enable_auto_assignment: true,
    greeting_enabled: true,
    greeting_message: "Hello! Thank you for contacting us via SMS."
  }
  
  create_response = make_api_request(
    'POST', 
    "/api/v1/accounts/#{ACCOUNT_ID}/inboxes", 
    inbox_data, 
    ADMIN_ACCESS_TOKEN
  )
  
  if create_response[:status] == 200 || create_response[:status] == 201
    inbox = create_response[:parsed]
    puts "✅ SUCCESS! Twilio SMS inbox created:"
    puts "   - Inbox ID: #{inbox['id']}"
    puts "   - Name: #{inbox['name']}"
    puts "   - Phone: #{TWILIO_CONFIG[:phone_number]}"
    puts "   - Webhook URL: #{CHATWOOT_BASE_URL}/twilio/callback"
    
    return inbox
  else
    puts "❌ Failed to create inbox:"
    puts "   Status: #{create_response[:status]}"
    puts "   Error: #{create_response[:parsed]}"
    return false
  end
end

# Method 2: Using Platform API (if available)
puts "\n📋 METHOD 2: Platform API Alternative"
puts "-" * 50

def create_via_platform_api
  puts "🔍 Note: Platform API may not support inbox creation"
  puts "   This is primarily for account/user management"
  puts "   You can try this endpoint if your platform app has permissions:"
  
  platform_example = {
    url: "https://voicelinkai-gateway.eastus.cloudapp.azure.com/platform/api/v1/accounts/#{ACCOUNT_ID}/inboxes",
    headers: {
      'Content-Type': 'application/json',
      'api_access_token': 'YkT9vdgc2UFZ2kgMhPdEaajT'
    },
    body: {
      name: TWILIO_CONFIG[:inbox_name],
      channel: {
        type: 'twilio_sms',
        account_sid: TWILIO_CONFIG[:account_sid],
        auth_token: TWILIO_CONFIG[:auth_token],
        phone_number: TWILIO_CONFIG[:phone_number],
        medium: 'sms'
      }
    }
  }
  
  puts "   curl -X POST \\"
  puts "     '#{platform_example[:url]}' \\"
  puts "     -H 'Content-Type: application/json' \\"
  puts "     -H 'api_access_token: #{platform_example[:headers][:api_access_token]}' \\"
  puts "     -d '#{platform_example[:body].to_json}'"
end

# Method 3: Getting Admin Access Token
puts "\n📋 METHOD 3: Getting Admin Access Token"
puts "-" * 50

def show_token_instructions
  puts "🔑 To get an admin access token:"
  puts ""
  puts "1. 📊 Via Chatwoot Dashboard:"
  puts "   - Login as admin user"
  puts "   - Go to Profile Settings → Access Token"
  puts "   - Create new token with required permissions"
  puts ""
  puts "2. 🛠️  Via Platform API (if you have platform access):"
  puts "   - Use existing platform token to create user tokens"
  puts "   - POST /platform/api/v1/accounts/{id}/users/{user_id}/access_tokens"
  puts ""
  puts "3. 🔧 Via Rails Console (last resort):"
  puts "   user = User.find_by(email: 'admin@example.com')"
  puts "   token = user.access_tokens.create!(name: 'API Token')"
  puts "   puts token.token"
end

# Main execution
puts "\n🚀 EXECUTING API-FIRST INBOX CREATION"
puts "=" * 60

if ADMIN_ACCESS_TOKEN == 'YOUR_ADMIN_ACCESS_TOKEN_HERE'
  puts "⚠️  Please update ADMIN_ACCESS_TOKEN before running"
  show_token_instructions
  puts "\n📝 Also update Twilio credentials in TWILIO_CONFIG"
  exit 1
end

if TWILIO_CONFIG[:account_sid] == 'AC1234567890abcdef1234567890abcdef'
  puts "⚠️  Please update Twilio credentials in TWILIO_CONFIG"
  exit 1
end

# Try to create the inbox
result = create_twilio_inbox_via_api

if result
  puts "\n🎉 INBOX CREATION SUCCESSFUL!"
  puts "\n📋 NEXT STEPS:"
  puts "1. 🌐 Configure Twilio webhook:"
  puts "   - URL: #{CHATWOOT_BASE_URL}/twilio/callback"
  puts "   - Method: POST"
  puts "   - Events: Incoming Messages"
  puts ""
  puts "2. 🧪 Test the integration:"
  puts "   - Send SMS to #{TWILIO_CONFIG[:phone_number]}"
  puts "   - Check Chatwoot for new conversation"
  puts ""
  puts "3. ✅ Verify via API:"
  puts "   GET #{CHATWOOT_BASE_URL}/api/v1/accounts/#{ACCOUNT_ID}/inboxes"
else
  puts "\n❌ Inbox creation failed. Check your credentials and try again."
  puts "\nTroubleshooting:"
  puts "- Verify admin access token has proper permissions"
  puts "- Check Twilio credentials are valid"
  puts "- Ensure phone number is in E.164 format (+1234567890)"
  puts "- Verify account #{ACCOUNT_ID} exists and you have access"
end

# Alternative Platform API approach
puts "\n" + "=" * 60
create_via_platform_api 