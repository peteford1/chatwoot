#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'uri'
require 'openssl'

# FIXED: API-First script to create Twilio SMS inbox for account 22
# Handles SSL certificate issues and connection problems

puts "🚀 Creating Twilio SMS inbox for Account 22 - FIXED Version"

# ========================================
# 📝 UPDATE THESE CONFIGURATION VALUES
# ========================================

# Chatwoot Configuration
CHATWOOT_BASE_URL = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
GATEWAY_URL = 'https://voicelinkai-gateway.eastus.cloudapp.azure.com'
ACCOUNT_ID = 22
ADMIN_ACCESS_TOKEN = 'YOUR_ADMIN_ACCESS_TOKEN_HERE'  # Get from Chatwoot dashboard
PLATFORM_TOKEN = 'YkT9vdgc2UFZ2kgMhPdEaajT'        # Platform API token

# Twilio Configuration  
TWILIO_CONFIG = {
  account_sid: 'AC1234567890abcdef1234567890abcdef',  # Your Twilio Account SID
  auth_token: 'your_twilio_auth_token_here',          # Your Twilio Auth Token
  phone_number: '+19999999999',                       # Your Twilio phone number (E.164 format)
  inbox_name: 'Account 22 Twilio SMS'                 # Name for the inbox
}

# ========================================
# 🛠️  FIXED API HELPER FUNCTIONS
# ========================================

def make_http_request(method, url, data = nil, headers = {})
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true if uri.scheme == 'https'
  
  # FIXED: Handle self-signed certificates for KrakenD
  if url.include?('voicelinkai-gateway')
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    puts "   ⚠️  SSL verification disabled for KrakenD gateway"
  end
  
  http.open_timeout = 15
  http.read_timeout = 30
  
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
  
  # Set headers
  request['Content-Type'] = 'application/json'
  headers.each { |k, v| request[k] = v }
  
  begin
    response = http.request(request)
    {
      success: response.code.to_i.between?(200, 299),
      status: response.code.to_i,
      body: response.body,
      parsed: (JSON.parse(response.body) rescue response.body),
      message: response.message
    }
  rescue => e
    {
      success: false,
      status: 0,
      body: e.message,
      parsed: { error: e.message },
      message: e.class.to_s
    }
  end
end

def test_backend_connection
  puts "\n🔍 Testing Chatwoot backend connection..."
  
  # Try different endpoints to see what works
  endpoints_to_try = [
    "#{CHATWOOT_BASE_URL}",
    "#{CHATWOOT_BASE_URL}/api/v1/accounts",
    "#{CHATWOOT_BASE_URL}/api/v1/profile"
  ]
  
  endpoints_to_try.each do |endpoint|
    puts "   Testing: #{endpoint}"
    response = make_http_request('GET', endpoint)
    puts "   Status: #{response[:status]} #{response[:message]}"
    
    if response[:success]
      puts "   ✅ Backend accessible at: #{endpoint}"
      return true
    end
  end
  
  puts "   ❌ Backend not accessible"
  return false
end

def try_create_via_gateway
  puts "\n🌐 Attempting inbox creation via KrakenD Gateway..."
  
  # Try Platform API first
  platform_endpoint = "#{GATEWAY_URL}/platform/api/v1/accounts/#{ACCOUNT_ID}/inboxes"
  
  inbox_data = {
    name: TWILIO_CONFIG[:inbox_name],
    channel: {
      type: 'twilio_sms',
      account_sid: TWILIO_CONFIG[:account_sid],
      auth_token: TWILIO_CONFIG[:auth_token],
      phone_number: TWILIO_CONFIG[:phone_number],
      medium: 'sms'
    }
  }
  
  headers = { 'api_access_token' => PLATFORM_TOKEN }
  
  response = make_http_request('POST', platform_endpoint, inbox_data, headers)
  
  if response[:success]
    puts "✅ SUCCESS via Platform API!"
    return response[:parsed]
  else
    puts "❌ Platform API failed: #{response[:status]} - #{response[:parsed]}"
    
    # Try regular API through gateway
    puts "\n🔄 Trying regular API through gateway..."
    
    if ADMIN_ACCESS_TOKEN != 'YOUR_ADMIN_ACCESS_TOKEN_HERE'
      regular_endpoint = "#{GATEWAY_URL}/api/v1/accounts/#{ACCOUNT_ID}/inboxes"
      headers = { 'Authorization' => "Bearer #{ADMIN_ACCESS_TOKEN}" }
      
      gateway_inbox_data = {
        name: TWILIO_CONFIG[:inbox_name],
        channel: {
          type: 'sms',
          phone_number: TWILIO_CONFIG[:phone_number],
          provider_config: {
            account_sid: TWILIO_CONFIG[:account_sid],
            auth_token: TWILIO_CONFIG[:auth_token],
            provider: 'twilio'
          }
        }
      }
      
      response = make_http_request('POST', regular_endpoint, gateway_inbox_data, headers)
      
      if response[:success]
        puts "✅ SUCCESS via Gateway regular API!"
        return response[:parsed]
      else
        puts "❌ Gateway regular API failed: #{response[:status]} - #{response[:parsed]}"
      end
    else
      puts "⚠️  No admin token configured for regular API"
    end
  end
  
  return false
end

def try_create_via_backend
  puts "\n🏢 Attempting inbox creation via direct backend..."
  
  if ADMIN_ACCESS_TOKEN == 'YOUR_ADMIN_ACCESS_TOKEN_HERE'
    puts "❌ Cannot try backend - no admin token configured"
    return false
  end
  
  backend_endpoint = "#{CHATWOOT_BASE_URL}/api/v1/accounts/#{ACCOUNT_ID}/inboxes"
  
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
  
  headers = { 'Authorization' => "Bearer #{ADMIN_ACCESS_TOKEN}" }
  
  response = make_http_request('POST', backend_endpoint, inbox_data, headers)
  
  if response[:success]
    puts "✅ SUCCESS via direct backend!"
    return response[:parsed]
  else
    puts "❌ Backend API failed: #{response[:status]} - #{response[:parsed]}"
    return false
  end
end

# ========================================
# 🚀 MAIN EXECUTION WITH FALLBACK STRATEGIES
# ========================================

begin
  # Validate configuration
  if TWILIO_CONFIG[:account_sid] == 'AC1234567890abcdef1234567890abcdef'
    puts "❌ Please update Twilio credentials in TWILIO_CONFIG"
    exit 1
  end
  
  puts "\n📋 Configuration Summary:"
  puts "   Account ID: #{ACCOUNT_ID}"
  puts "   Phone Number: #{TWILIO_CONFIG[:phone_number]}"
  puts "   Inbox Name: #{TWILIO_CONFIG[:inbox_name]}"
  puts "   Admin Token: #{ADMIN_ACCESS_TOKEN != 'YOUR_ADMIN_ACCESS_TOKEN_HERE' ? 'Configured' : 'NOT CONFIGURED'}"
  puts "   Platform Token: #{PLATFORM_TOKEN[0..10]}..."
  
  # Strategy 1: Try KrakenD Gateway (handles SSL issues)
  puts "\n" + "="*60
  puts "STRATEGY 1: Using KrakenD Gateway"
  puts "="*60
  
  result = try_create_via_gateway
  
  if result
    puts "\n🎉 INBOX CREATION SUCCESSFUL!"
    puts "   Method: KrakenD Gateway"
    puts "   Inbox: #{result}"
  else
    # Strategy 2: Try direct backend
    puts "\n" + "="*60
    puts "STRATEGY 2: Using Direct Backend"
    puts "="*60
    
    backend_ok = test_backend_connection
    
    if backend_ok
      result = try_create_via_backend
      
      if result
        puts "\n🎉 INBOX CREATION SUCCESSFUL!"
        puts "   Method: Direct Backend"
        puts "   Inbox: #{result}"
      end
    end
  end
  
  if result
    puts "\n📋 NEXT STEPS:"
    puts "1. 🌐 Configure Twilio webhook:"
    puts "   - Login to Twilio Console"
    puts "   - Go to Phone Numbers → Manage"
    puts "   - Set webhook URL to one of these:"
    puts "     • #{GATEWAY_URL}/twilio/callback (preferred)"
    puts "     • #{CHATWOOT_BASE_URL}/twilio/callback (alternative)"
    puts ""
    puts "2. 🧪 Test with SMS:"
    puts "   Send message to #{TWILIO_CONFIG[:phone_number]}"
    puts ""
    puts "3. ✅ Verify in Chatwoot dashboard"
    
  else
    puts "\n❌ ALL CREATION STRATEGIES FAILED"
    puts "\n🔧 Manual alternatives:"
    puts "1. Create via Chatwoot dashboard UI"
    puts "2. Check server logs for specific errors"
    puts "3. Verify network connectivity and SSL certificates"
    puts "4. Try with different authentication tokens"
    
    puts "\n🛠️  Debug commands to try:"
    puts "curl -k -I #{GATEWAY_URL}"
    puts "curl -I #{CHATWOOT_BASE_URL}"
    puts "openssl s_client -connect voicelinkai-gateway.eastus.cloudapp.azure.com:443"
  end
  
rescue Interrupt
  puts "\n\n⏹️  Operation cancelled by user"
  exit 1
rescue => e
  puts "\n❌ Unexpected error:"
  puts "   #{e.class}: #{e.message}"
  puts "   Location: #{e.backtrace.first}"
  
  puts "\n🔧 This error suggests:"
  if e.message.include?('SSL')
    puts "   - SSL/TLS certificate issue"
    puts "   - Try: curl -k #{GATEWAY_URL}"
  elsif e.message.include?('Connection')
    puts "   - Network connectivity issue"
    puts "   - Check if servers are running"
  elsif e.message.include?('JSON')
    puts "   - API response format issue"
    puts "   - Server might be returning HTML instead of JSON"
  else
    puts "   - Unknown issue, check server status"
  end
  
  exit 1
end 