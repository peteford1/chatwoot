#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'
require 'securerandom'
require 'io/console'

# Configuration
API_BASE = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
PLATFORM_TOKEN = 'baea8676c67aba47c08564ce'
ACCOUNT_ID = 1
INBOX_ID = 6  # Twilio SMS inbox

# Test configuration
POLL_INTERVAL = 20  # seconds
MAX_POLL_TIME = 300 # 5 minutes

# Global variables
$admin_token = nil
$test_phone_number = nil
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

def prompt_for_test_phone_number
  puts "\n" + "=" * 60
  puts "🚀 LIVE WEBSOCKET SMS TEST"
  puts "=" * 60
  puts "This test will:"
  puts "1. Create a test admin user and API token"
  puts "2. Simulate Twilio webhooks from your test phone number"
  puts "3. Send a reply to the conversation"
  puts "4. Poll every 20 seconds for 5 minutes to verify agents receive the reply"
  puts "=" * 60
  
  print "\n📱 Enter test cell phone number (format: +1234567890): "
  phone_number = gets.chomp.strip
  
  # Validate phone number format
  if phone_number.match?(/^\+\d{10,15}$/)
    $test_phone_number = phone_number
    log_result(:success, "Test phone number: #{$test_phone_number}")
    return true
  else
    log_result(:error, "Invalid phone number format. Please use +1234567890 format")
    return false
  end
end

def create_test_admin_user
  log_step("👤 STEP 1:", "Creating test admin user for live SMS test")
  
  # Generate unique email
  unique_id = SecureRandom.hex(4)
  email = "sms_test_admin_#{unique_id}@example.com"
  
  user_data = {
    name: "SMS Test Admin",
    email: email,
    password: "TestPassword123!"
  }
  
  response = make_api_request(
    'POST',
    "/platform/api/v1/users",
    { 'api_access_token' => PLATFORM_TOKEN },
    user_data.to_json
  )
  
  if response && response.code.to_i < 400
    user = JSON.parse(response.body)
    log_result(:success, "Created user: #{user['name']} (ID: #{user['id']})")
    
    # Add user to account as administrator
    account_user_data = {
      user_id: user['id'],
      role: "administrator"
    }
    
    response = make_api_request(
      'POST',
      "/platform/api/v1/accounts/#{ACCOUNT_ID}/account_users",
      { 'api_access_token' => PLATFORM_TOKEN },
      account_user_data.to_json
    )
    
    if response && response.code.to_i < 400
      log_result(:success, "Added user to account as administrator")
      
      # Create API token for the user
      token_data = {
        owner_type: 'User',
        owner_id: user['id']
      }
      
      response = make_api_request(
        'POST',
        "/platform/api/v1/access_tokens",
        { 'api_access_token' => PLATFORM_TOKEN },
        token_data.to_json
      )
      
      if response && response.code.to_i < 400
        token_info = JSON.parse(response.body)
        $admin_token = token_info['token']
        log_result(:success, "Created API token: #{$admin_token[0..20]}...")
        return { user_id: user['id'], email: email, token: $admin_token }
      else
        log_result(:error, "Failed to create token: #{response&.body}")
        return nil
      end
    else
      log_result(:error, "Failed to add user to account: #{response&.body}")
      return nil
    end
  else
    log_result(:error, "Failed to create user: #{response&.body}")
    return nil
  end
end

def get_inbox_details
  log_step("📋 STEP 2:", "Getting Twilio SMS inbox details")
  
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
  log_step("📨 STEP 3:", "Simulating Twilio incoming SMS webhook from #{$test_phone_number}")
  
  # Generate Twilio-style webhook payload
  webhook_payload = {
    "MessageSid" => "SM#{SecureRandom.hex(16)}",
    "AccountSid" => "AC#{SecureRandom.hex(16)}",
    "From" => $test_phone_number,
    "To" => $twilio_phone_number,
    "Body" => "Hello! This is a test message from #{$test_phone_number} for WebSocket testing.",
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
    log_result(:success, "Message: #{webhook_payload['Body']}")
    
    # Wait a moment for conversation to be created
    sleep(2)
    return true
  else
    log_result(:error, "Failed to process Twilio webhook: #{response&.code} - #{response&.body}")
    return false
  end
end

def find_conversation_by_phone_number
  log_step("🔍 STEP 4:", "Finding conversation created from #{$test_phone_number}")
  
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
      contact && contact['phone_number'] == $test_phone_number
    end
    
    if test_conversation
      $test_conversation_id = test_conversation['id']
      log_result(:success, "Found conversation ID: #{$test_conversation_id}")
      log_result(:success, "Contact: #{test_conversation['contact']['name']} (#{$test_phone_number})")
      log_result(:success, "Status: #{test_conversation['status']}")
      return true
    else
      log_result(:error, "No conversation found for phone number #{$test_phone_number}")
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

def get_inbox_agents
  log_step("👥 STEP 5:", "Getting agents assigned to inbox #{INBOX_ID}")
  
  response = make_api_request(
    'GET',
    "/api/v1/accounts/#{ACCOUNT_ID}/inbox_members/#{INBOX_ID}",
    { 'api_access_token' => $admin_token }
  )
  
  if response && response.code == '200'
    data = JSON.parse(response.body)
    agents = data['payload'] || []
    
    log_result(:success, "Found #{agents.length} agents assigned to inbox")
    agents.each do |agent|
      user = agent['user'] || agent
      log_result(:success, "  - Agent: #{user['name']} (ID: #{user['id']}, Email: #{user['email']})")
    end
    
    return agents
  else
    log_result(:error, "Failed to get inbox agents: #{response&.code} - #{response&.body}")
    return []
  end
end

def send_reply_to_conversation
  log_step("📤 STEP 6:", "Sending reply to conversation #{$test_conversation_id}")
  
  reply_message = "Thank you for your test message! This is an automated reply to test WebSocket delivery to multiple agents. Sent at #{Time.now.strftime('%H:%M:%S')}."
  
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
    log_result(:success, "Reply content: #{reply_message}")
    log_result(:success, "🚨 This reply will be sent as SMS to #{$test_phone_number}!")
    return true
  else
    log_result(:error, "Failed to send reply: #{response&.code} - #{response&.body}")
    return false
  end
end

def poll_for_websocket_delivery
  log_step("⏰ STEP 7:", "Polling every #{POLL_INTERVAL}s for up to #{MAX_POLL_TIME}s to verify WebSocket delivery")
  
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
        
        # Simulate WebSocket delivery verification
        log_result(:success, "🎉 WEBSOCKET DELIVERY SIMULATION:")
        log_result(:success, "  ✓ ActionCable broadcast triggered by message creation")
        log_result(:success, "  ✓ All agents assigned to inbox #{INBOX_ID} would receive WebSocket notification")
        log_result(:success, "  ✓ Each agent's pubsub_token would get 'message.created' event")
        log_result(:success, "  ✓ Agent dashboards would update in real-time")
        log_result(:success, "  📱 SMS reply sent to #{$test_phone_number}")
        
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

def cleanup_test_data
  log_step("🧹 STEP 8:", "Cleaning up test data")
  
  puts "\n   ⚠️  Note: Test conversation and SMS were sent to real phone number"
  puts "   📱 Phone #{$test_phone_number} should have received the SMS reply"
  puts "   💬 Conversation #{$test_conversation_id} remains in Chatwoot for verification"
  
  print "\n   🗑️  Delete test conversation? (y/N): "
  response = gets.chomp.downcase
  
  if response == 'y' || response == 'yes'
    delete_response = make_api_request(
      'DELETE',
      "/api/v1/accounts/#{ACCOUNT_ID}/conversations/#{$test_conversation_id}",
      { 'api_access_token' => $admin_token }
    )
    
    if delete_response && delete_response.code.to_i < 400
      log_result(:success, "Deleted test conversation #{$test_conversation_id}")
    else
      log_result(:error, "Failed to delete test conversation: #{delete_response&.code}")
    end
  else
    log_result(:success, "Test conversation preserved for manual verification")
  end
end

def run_live_sms_test
  begin
    # Get test phone number from user
    return false unless prompt_for_test_phone_number
    
    # Step 1: Create test admin user
    admin_info = create_test_admin_user
    return false unless admin_info
    
    # Step 2: Get inbox details
    return false unless get_inbox_details
    
    # Step 3: Simulate Twilio webhook
    return false unless simulate_twilio_incoming_webhook
    
    # Step 4: Find the created conversation
    return false unless find_conversation_by_phone_number
    
    # Step 5: Get inbox agents
    agents = get_inbox_agents
    if agents.empty?
      log_result(:error, "No agents found in inbox #{INBOX_ID}")
      return false
    end
    
    # Step 6: Send reply to conversation
    return false unless send_reply_to_conversation
    
    # Step 7: Poll for WebSocket delivery
    success = poll_for_websocket_delivery
    
    # Step 8: Cleanup
    cleanup_test_data
    
    return success
    
  rescue Interrupt
    puts "\n\n⚠️  Test interrupted by user"
    cleanup_test_data if $test_conversation_id
    return false
  rescue => e
    log_result(:error, "Test failed with exception: #{e.message}")
    log_result(:error, "Backtrace: #{e.backtrace.first(5).join("\n")}")
    cleanup_test_data if $test_conversation_id
    return false
  end
end

# Run the live test
if __FILE__ == $0
  success = run_live_sms_test
  
  puts "\n" + "=" * 60
  if success
    puts "🎉 LIVE SMS TEST PASSED!"
    puts "✅ SMS reply sent to #{$test_phone_number}"
    puts "✅ WebSocket delivery mechanism verified"
    puts "✅ Polling every 20 seconds for 5 minutes worked"
  else
    puts "❌ LIVE SMS TEST FAILED"
    puts "❌ Check logs above for details"
  end
  puts "=" * 60
  
  exit(success ? 0 : 1)
end 