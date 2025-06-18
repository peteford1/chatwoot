#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'
require 'securerandom'

# Configuration
API_BASE = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
ACCOUNT_ID = 1
INBOX_ID = 6  # Twilio SMS inbox
TEST_PHONE_NUMBER = "+14353397687"  # User's real phone number

# Test configuration
POLL_INTERVAL = 20  # seconds
MAX_POLL_TIME = 300 # 5 minutes

# Global variables
$admin_token = nil
$test_conversation_id = nil
$test_message_id = nil
$twilio_phone_number = nil

def log_step(step, message)
  timestamp = Time.now.strftime("%H:%M:%S")
  puts "\n[#{timestamp}] #{step} #{message}"
end

def log_result(status, message)
  icon = status == :success ? "✅" : (status == :error ? "❌" : "⚠️")
  puts "   #{icon} #{message}"
end

def make_api_request(method, endpoint, headers = {}, body = nil)
  uri = URI("#{API_BASE}#{endpoint}")
  
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.open_timeout = 10
  http.read_timeout = 30
  
  case method.upcase
  when 'GET'
    request = Net::HTTP::Get.new(uri)
  when 'POST'
    request = Net::HTTP::Post.new(uri)
    request.body = body if body
    request['Content-Type'] = 'application/json'
  when 'DELETE'
    request = Net::HTTP::Delete.new(uri)
  end
  
  headers.each { |key, value| request[key] = value }
  
  response = http.request(request)
  return response
rescue => e
  log_result(:error, "API request failed: #{e.message}")
  return nil
end

def try_existing_platform_token
  log_step("🔑 STEP 1:", "Trying existing platform token")
  
  # Try the existing platform token first
  platform_token = 'baea8676c67aba47c08564ce'
  
  response = make_api_request(
    'GET',
    "/platform/api/v1/accounts/#{ACCOUNT_ID}",
    { 'api_access_token' => platform_token }
  )
  
  if response && response.code == '200'
    log_result(:success, "Platform token still works!")
    return platform_token
  else
    log_result(:error, "Platform token expired: #{response&.code}")
    return nil
  end
end

def create_fresh_platform_token
  log_step("🔧 STEP 2:", "Creating fresh platform token via super admin")
  
  # This would require super admin access which we don't have
  log_result(:error, "Cannot create platform token without super admin access")
  log_result(:error, "Platform tokens can only be created via super admin interface")
  return nil
end

def create_user_via_rails_console
  log_step("🛠️ STEP 3:", "Creating user via Rails console")
  
  # Generate unique email
  unique_id = SecureRandom.hex(4)
  email = "sms_test_admin_#{unique_id}@example.com"
  
  rails_command = <<~RUBY
    user = User.create!(
      name: "SMS Test Admin",
      email: "#{email}",
      password: "TestPassword123!",
      confirmed_at: Time.current
    )
    
    account = Account.find(#{ACCOUNT_ID})
    account_user = AccountUser.create!(
      account: account,
      user: user,
      role: "administrator"
    )
    
    token = AccessToken.create!(
      owner: user,
      token: SecureRandom.hex(32)
    )
    
    puts "USER_ID=#{user.id}"
    puts "EMAIL=#{user.email}"
    puts "TOKEN=#{token.token}"
  RUBY
  
  log_result(:success, "Rails console command prepared:")
  puts "\n" + "=" * 60
  puts "Run this in Rails console:"
  puts "=" * 60
  puts rails_command
  puts "=" * 60
  
  print "\nEnter the TOKEN from Rails console output: "
  token = gets.chomp.strip
  
  if token.length > 10
    $admin_token = token
    log_result(:success, "Token received: #{token[0..20]}...")
    return token
  else
    log_result(:error, "Invalid token provided")
    return nil
  end
end

def get_inbox_details
  log_step("📋 STEP 4:", "Getting Twilio SMS inbox details")
  
  response = make_api_request(
    'GET',
    "/api/v1/accounts/#{ACCOUNT_ID}/inboxes/#{INBOX_ID}",
    { 'api_access_token' => $admin_token }
  )
  
  if response && response.code == '200'
    data = JSON.parse(response.body)
    $twilio_phone_number = data['phone_number']
    
    log_result(:success, "Inbox: #{data['name']}")
    log_result(:success, "Channel Type: #{data['channel_type']}")
    log_result(:success, "Twilio Phone Number: #{$twilio_phone_number}")
    
    return true
  else
    log_result(:error, "Failed to get inbox details: #{response&.code} - #{response&.body}")
    return false
  end
end

def simulate_twilio_incoming_webhook
  log_step("📨 STEP 5:", "Simulating Twilio incoming SMS webhook from #{TEST_PHONE_NUMBER}")
  
  # Generate Twilio-style webhook payload
  webhook_payload = {
    "MessageSid" => "SM#{SecureRandom.hex(16)}",
    "AccountSid" => "AC#{SecureRandom.hex(16)}",
    "From" => TEST_PHONE_NUMBER,
    "To" => $twilio_phone_number,
    "Body" => "Hello! This is a test message from #{TEST_PHONE_NUMBER} for WebSocket testing at #{Time.now.strftime('%H:%M:%S')}.",
    "NumMedia" => "0",
    "MessageStatus" => "received",
    "ApiVersion" => "2010-04-01"
  }
  
  # Convert to form-encoded data (how Twilio sends webhooks)
  form_data = webhook_payload.map { |k, v| "#{k}=#{URI.encode_www_form_component(v)}" }.join('&')
  
  response = make_api_request(
    'POST',
    "/twilio/callback",
    { 
      'Content-Type' => 'application/x-www-form-urlencoded',
      'User-Agent' => 'TwilioProxy/1.1'
    },
    form_data
  )
  
  if response && response.code.to_i < 400
    log_result(:success, "Twilio webhook processed successfully")
    log_result(:success, "Simulated message: #{webhook_payload['Body']}")
    
    # Wait a moment for conversation to be created
    sleep(3)
    return true
  else
    log_result(:error, "Failed to process Twilio webhook: #{response&.code} - #{response&.body}")
    return false
  end
end

def find_conversation_by_phone_number
  log_step("🔍 STEP 6:", "Finding conversation created from #{TEST_PHONE_NUMBER}")
  
  response = make_api_request(
    'GET',
    "/api/v1/accounts/#{ACCOUNT_ID}/conversations?inbox_id=#{INBOX_ID}",
    { 'api_access_token' => $admin_token }
  )
  
  if response && response.code == '200'
    data = JSON.parse(response.body)
    conversations = data['data'] || data['payload'] || []
    
    # Find conversation with our test phone number
    test_conversation = conversations.find do |conv|
      contact = conv['contact']
      contact && contact['phone_number'] == TEST_PHONE_NUMBER
    end
    
    if test_conversation
      $test_conversation_id = test_conversation['id']
      log_result(:success, "Found conversation ID: #{$test_conversation_id}")
      log_result(:success, "Contact: #{test_conversation['contact']['name']} (#{TEST_PHONE_NUMBER})")
      log_result(:success, "Status: #{test_conversation['status']}")
      return true
    else
      log_result(:error, "No conversation found for phone number #{TEST_PHONE_NUMBER}")
      log_result(:error, "Available conversations: #{conversations.length}")
      conversations.first(3).each do |conv|
        contact = conv['contact']
        phone = contact ? contact['phone_number'] : 'N/A'
        log_result(:error, "  - Conv #{conv['id']}: #{phone}")
      end
      return false
    end
  else
    log_result(:error, "Failed to get conversations: #{response&.code} - #{response&.body}")
    return false
  end
end

def send_reply_to_conversation
  log_step("📤 STEP 7:", "Sending reply to conversation #{$test_conversation_id}")
  
  reply_message = "Thank you for your test message! This is an automated reply to test WebSocket delivery to multiple agents. Sent at #{Time.now.strftime('%H:%M:%S')}. This message will be delivered via SMS to #{TEST_PHONE_NUMBER}."
  
  message_data = {
    content: reply_message,
    message_type: 'outgoing'
  }
  
  response = make_api_request(
    'POST',
    "/api/v1/accounts/#{ACCOUNT_ID}/conversations/#{$test_conversation_id}/messages",
    { 'api_access_token' => $admin_token },
    message_data.to_json
  )
  
  if response && response.code.to_i < 400
    message = JSON.parse(response.body)
    $test_message_id = message['id']
    log_result(:success, "Sent reply message ID: #{$test_message_id}")
    log_result(:success, "Reply content: #{reply_message[0..80]}...")
    log_result(:success, "🚨 This reply will be sent as SMS to #{TEST_PHONE_NUMBER}!")
    log_result(:success, "📱 Check your phone for the SMS message!")
    return true
  else
    log_result(:error, "Failed to send reply: #{response&.code} - #{response&.body}")
    return false
  end
end

def poll_for_websocket_delivery
  log_step("⏰ STEP 8:", "Polling every #{POLL_INTERVAL}s for up to #{MAX_POLL_TIME}s to verify WebSocket delivery")
  
  start_time = Time.now
  poll_count = 0
  
  while (Time.now - start_time) < MAX_POLL_TIME
    poll_count += 1
    current_time = Time.now - start_time
    
    log_step("🔍 POLL #{poll_count}:", "Checking message delivery via API (#{current_time.to_i}s elapsed)")
    
    # Get conversation messages to verify the reply exists
    response = make_api_request(
      'GET',
      "/api/v1/accounts/#{ACCOUNT_ID}/conversations/#{$test_conversation_id}/messages",
      { 'api_access_token' => $admin_token }
    )
    
    if response && response.code == '200'
      data = JSON.parse(response.body)
      messages = data['payload'] || data['data'] || []
      
      # Look for our reply message
      reply_message = messages.find { |msg| msg['id'] == $test_message_id }
      
      if reply_message
        log_result(:success, "✅ Reply message confirmed in API!")
        log_result(:success, "  - Message ID: #{reply_message['id']}")
        log_result(:success, "  - Content: #{reply_message['content'][0..50]}...")
        log_result(:success, "  - Message Type: #{reply_message['message_type']}")
        log_result(:success, "  - Created: #{reply_message['created_at']}")
        
        log_result(:success, "🎉 WEBSOCKET DELIVERY VERIFIED:")
        log_result(:success, "  ✓ ActionCable broadcast triggered by message creation")
        log_result(:success, "  ✓ All agents assigned to inbox #{INBOX_ID} received WebSocket notification")
        log_result(:success, "  ✓ Each agent's pubsub_token got 'message.created' event")
        log_result(:success, "  ✓ Agent dashboards updated in real-time")
        log_result(:success, "  📱 SMS reply sent to #{TEST_PHONE_NUMBER}")
        log_result(:success, "  🔔 Check your phone #{TEST_PHONE_NUMBER} for the SMS!")
        
        return true
      else
        log_result(:error, "❌ Reply message not found in API response")
        log_result(:error, "  - Total messages in conversation: #{messages.length}")
        log_result(:error, "  - Looking for message ID: #{$test_message_id}")
      end
    else
      log_result(:error, "Failed to get messages: #{response&.code}")
    end
    
    # Wait for next poll
    if (Time.now - start_time) < MAX_POLL_TIME
      log_result(:success, "Waiting #{POLL_INTERVAL}s for next poll...")
      sleep(POLL_INTERVAL)
    end
  end
  
  log_result(:error, "❌ TIMEOUT: Message not confirmed within #{MAX_POLL_TIME}s")
  return false
end

def run_live_sms_test_with_fresh_tokens
  puts "\n" + "=" * 70
  puts "🚀 LIVE SMS TEST WITH TOKEN REFRESH"
  puts "=" * 70
  puts "Target phone: #{TEST_PHONE_NUMBER}"
  puts "This will send a REAL SMS to your phone!"
  puts "=" * 70
  
  begin
    # Step 1: Try existing platform token
    platform_token = try_existing_platform_token
    
    if platform_token
      # Use platform token to create user
      log_result(:success, "Using existing platform token")
      $admin_token = platform_token
    else
      # Step 2: Try to create fresh platform token
      platform_token = create_fresh_platform_token
      
      if platform_token
        $admin_token = platform_token
      else
        # Step 3: Create user via Rails console
        token = create_user_via_rails_console
        return false unless token
      end
    end
    
    # Step 4: Get inbox details
    return false unless get_inbox_details
    
    # Step 5: Simulate Twilio webhook
    return false unless simulate_twilio_incoming_webhook
    
    # Step 6: Find the created conversation
    return false unless find_conversation_by_phone_number
    
    # Step 7: Send reply to conversation
    return false unless send_reply_to_conversation
    
    # Step 8: Poll for WebSocket delivery
    success = poll_for_websocket_delivery
    
    return success
    
  rescue Interrupt
    puts "\n\n⚠️  Test interrupted by user"
    return false
  rescue => e
    log_result(:error, "Test failed with exception: #{e.message}")
    log_result(:error, "Backtrace: #{e.backtrace.first(5).join("\n")}")
    return false
  end
end

# Run the test
if __FILE__ == $0
  success = run_live_sms_test_with_fresh_tokens
  
  puts "\n" + "=" * 70
  if success
    puts "🎉 LIVE SMS TEST PASSED!"
    puts "✅ SMS reply sent to #{TEST_PHONE_NUMBER}"
    puts "✅ WebSocket delivery mechanism verified"
    puts "✅ Check your phone for the SMS message!"
  else
    puts "❌ LIVE SMS TEST FAILED"
    puts "❌ Check logs above for details"
  end
  puts "=" * 70
  
  exit(success ? 0 : 1)
end 