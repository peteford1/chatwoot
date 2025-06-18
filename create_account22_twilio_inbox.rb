#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'uri'

# API-First script to create Twilio SMS inbox for account 22
# Uses Chatwoot's REST API instead of direct database access

puts "🚀 Creating Twilio SMS inbox for Account 22 - API-First Approach"

# ========================================
# 📝 UPDATE THESE CONFIGURATION VALUES
# ========================================

# Chatwoot Configuration
CHATWOOT_BASE_URL = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
ACCOUNT_ID = 22
ADMIN_ACCESS_TOKEN = 'YOUR_ADMIN_ACCESS_TOKEN_HERE'  # Get from Chatwoot dashboard or create new

# Twilio Configuration  
TWILIO_CONFIG = {
  account_sid: 'AC1234567890abcdef1234567890abcdef',  # Your Twilio Account SID
  auth_token: 'your_twilio_auth_token_here',          # Your Twilio Auth Token
  phone_number: '+19999999999',                       # Your Twilio phone number (E.164 format)
  inbox_name: 'Account 22 Twilio SMS'                 # Name for the inbox
}

# ========================================
# 🛠️  API HELPER FUNCTIONS
# ========================================

def make_chatwoot_request(method, endpoint, data = nil)
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
  request['Authorization'] = "Bearer #{ADMIN_ACCESS_TOKEN}"
  
  begin
    response = http.request(request)
    {
      success: response.code.to_i.between?(200, 299),
      status: response.code.to_i,
      body: response.body,
      parsed: (JSON.parse(response.body) rescue response.body)
    }
  rescue => e
    {
      success: false,
      status: 0,
      body: e.message,
      parsed: { error: e.message }
    }
  end
end

def check_existing_inbox(phone_number)
  puts "🔍 Checking for existing Twilio inbox with phone #{phone_number}..."
  
  response = make_chatwoot_request('GET', "/api/v1/accounts/#{ACCOUNT_ID}/inboxes")
  
  if response[:success]
    inboxes = response[:parsed]
    existing = inboxes.find do |inbox| 
      inbox.dig('channel', 'phone_number') == phone_number
    end
    
    if existing
      puts "⚠️  Existing inbox found:"
      puts "   - ID: #{existing['id']}"
      puts "   - Name: #{existing['name']}"
      puts "   - Phone: #{existing.dig('channel', 'phone_number')}"
      return existing
    else
      puts "✅ No existing inbox found for phone #{phone_number}"
      return nil
    end
  else
    puts "❌ Failed to check existing inboxes: #{response[:parsed]}"
    return nil
  end
end

# ========================================
# 🚀 MAIN EXECUTION
# ========================================

begin
  # Validate configuration
  if ADMIN_ACCESS_TOKEN == 'YOUR_ADMIN_ACCESS_TOKEN_HERE'
    puts "❌ Please update ADMIN_ACCESS_TOKEN in the script"
    puts "\n🔑 How to get an access token:"
    puts "1. Login to Chatwoot dashboard"
    puts "2. Go to Profile Settings → Access Token"
    puts "3. Create new token with admin permissions" 
    puts "4. Copy token and update ADMIN_ACCESS_TOKEN in this script"
    exit 1
  end
  
  if TWILIO_CONFIG[:account_sid] == 'AC1234567890abcdef1234567890abcdef'
    puts "❌ Please update Twilio credentials in TWILIO_CONFIG"
    exit 1
  end
  
  puts "\n🔍 Step 1: Verifying account access..."
  
  # Verify account exists and we have access
  account_response = make_chatwoot_request('GET', "/api/v1/accounts/#{ACCOUNT_ID}")
  
  unless account_response[:success]
    puts "❌ Cannot access account #{ACCOUNT_ID}"
    puts "   Status: #{account_response[:status]}"
    puts "   Error: #{account_response[:parsed]}"
    puts "\n💡 Possible issues:"
    puts "   - Account doesn't exist"
    puts "   - Access token doesn't have permission"
    puts "   - Wrong account ID"
    exit 1
  end
  
  account = account_response[:parsed]
  puts "✅ Account verified: #{account['name']} (ID: #{account['id']})"
  
  # Check for existing inbox
  existing_inbox = check_existing_inbox(TWILIO_CONFIG[:phone_number])
  if existing_inbox
    puts "\n🛑 Inbox already exists. Skipping creation."
    puts "   Use the existing inbox or change the phone number."
    exit 0
  end
  
  puts "\n📱 Step 2: Creating Twilio SMS inbox via API..."
  
  # Prepare inbox data for API call
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
  
  # Create inbox via API
  create_response = make_chatwoot_request(
    'POST', 
    "/api/v1/accounts/#{ACCOUNT_ID}/inboxes", 
    inbox_data
  )
  
  if create_response[:success]
    inbox = create_response[:parsed]
    
    puts "🎉 SUCCESS! Twilio SMS inbox created via API:"
    puts "   - Inbox ID: #{inbox['id']}"
    puts "   - Name: #{inbox['name']}"
    puts "   - Channel Type: #{inbox['channel_type']}"
    puts "   - Phone Number: #{TWILIO_CONFIG[:phone_number]}"
    puts "   - Auto Assignment: #{inbox['enable_auto_assignment']}"
    puts "   - Greeting Enabled: #{inbox['greeting_enabled']}"
    
    puts "\n📋 NEXT STEPS:"
    puts "1. 🌐 Configure Twilio webhook URL:"
    puts "   - Login to Twilio Console"
    puts "   - Go to Phone Numbers → Manage → Active numbers"
    puts "   - Select #{TWILIO_CONFIG[:phone_number]}"
    puts "   - Set webhook URL: #{CHATWOOT_BASE_URL}/twilio/callback"
    puts "   - Method: HTTP POST"
    puts ""
    puts "2. 🧪 Test the integration:"
    puts "   - Send SMS to #{TWILIO_CONFIG[:phone_number]}"
    puts "   - Check Chatwoot dashboard for new conversation"
    puts ""
    puts "3. ✅ Verify inbox via API:"
    puts "   GET #{CHATWOOT_BASE_URL}/api/v1/accounts/#{ACCOUNT_ID}/inboxes/#{inbox['id']}"
    puts ""
    puts "4. 🔧 Test webhook manually:"
    puts "   curl -X POST '#{CHATWOOT_BASE_URL}/twilio/callback' \\"
    puts "     -H 'Content-Type: application/x-www-form-urlencoded' \\"
    puts "     -d 'From=+1234567890&To=#{TWILIO_CONFIG[:phone_number]}&Body=Test message&AccountSid=#{TWILIO_CONFIG[:account_sid]}'"
    
  else
    puts "❌ Failed to create inbox via API:"
    puts "   Status: #{create_response[:status]}"
    puts "   Error: #{create_response[:parsed]}"
    
    puts "\n🔧 Troubleshooting:"
    puts "   - Verify Twilio credentials are correct"
    puts "   - Check phone number format (must be E.164: +1234567890)"
    puts "   - Ensure account_sid starts with 'AC'"
    puts "   - Verify auth_token is valid"
    puts "   - Check if phone number is already in use"
    puts "   - Confirm admin access token has inbox creation permissions"
    
    exit 1
  end
  
rescue Interrupt
  puts "\n\n⏹️  Operation cancelled by user"
  exit 1
rescue => e
  puts "\n❌ Unexpected error:"
  puts "   #{e.class}: #{e.message}"
  puts "   #{e.backtrace.first}"
  
  puts "\n🔧 Please check:"
  puts "   - Network connectivity"
  puts "   - Chatwoot server status"
  puts "   - API token validity"
  puts "   - Configuration values"
  
  exit 1
end 