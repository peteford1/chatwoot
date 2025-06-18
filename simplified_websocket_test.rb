#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

# Configuration
API_BASE = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
PLATFORM_TOKEN = 'baea8676c67aba47c08564ce'  # This should be the platform token
ACCOUNT_ID = 1
INBOX_ID = 6

# Test configuration
POLL_INTERVAL = 20  # seconds
MAX_POLL_TIME = 300 # 5 minutes
TEST_MESSAGE = "WebSocket polling test - #{Time.now.to_i}"

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
  end
  
  headers.each { |key, value| request[key] = value }
  
  response = http.request(request)
  return response
rescue => e
  log_result(:error, "API request failed: #{e.message}")
  return nil
end

def create_test_admin_user
  log_step("👤 STEP 1:", "Creating test admin user")
  
  # Generate unique email
  unique_id = SecureRandom.hex(4)
  email = "websocket_test_#{unique_id}@example.com"
  
  user_data = {
    name: "WebSocket Test Admin",
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
      return { user_id: user['id'], email: email }
    else
      log_result(:error, "Failed to add user to account: #{response&.body}")
      return nil
    end
  else
    log_result(:error, "Failed to create user: #{response&.body}")
    return nil
  end
end

def get_user_api_token(email)
  log_step("🔑 STEP 2:", "Getting user API token")
  
  # Try to get user details via platform API
  response = make_api_request(
    'GET',
    "/platform/api/v1/users?email=#{email}",
    { 'api_access_token' => PLATFORM_TOKEN }
  )
  
  if response && response.code == '200'
    users = JSON.parse(response.body)
    if users.any?
      user = users.first
      # Create an access token for the user
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
        log_result(:success, "Created API token: #{token_info['token'][0..20]}...")
        return token_info['token']
      else
        log_result(:error, "Failed to create token: #{response&.body}")
        return nil
      end
    else
      log_result(:error, "User not found")
      return nil
    end
  else
    log_result(:error, "Failed to get user: #{response&.body}")
    return nil
  end
end

def get_inbox_conversations(api_token)
  log_step("📥 STEP 3:", "Getting conversations from inbox #{INBOX_ID}")
  
  response = make_api_request(
    'GET',
    "/api/v1/accounts/#{ACCOUNT_ID}/conversations?inbox_id=#{INBOX_ID}&status=all",
    { 'api_access_token' => api_token }
  )
  
  if response && response.code == '200'
    data = JSON.parse(response.body)
    conversations = data['data'] || data['payload'] || []
    log_result(:success, "Found #{conversations.length} conversations in inbox")
    return conversations
  else
    log_result(:error, "Failed to get conversations: #{response&.code} - #{response&.body}")
    return []
  end
end

def create_test_conversation(api_token)
  log_step("💬 STEP 4:", "Creating test conversation")
  
  conversation_data = {
    source_id: "websocket_poll_test_#{Time.now.to_i}",
    inbox_id: INBOX_ID,
    contact_attributes: {
      name: "WebSocket Poll Test Contact",
      email: "poll.test@example.com"
    }
  }
  
  response = make_api_request(
    'POST',
    "/api/v1/accounts/#{ACCOUNT_ID}/conversations",
    { 'api_access_token' => api_token },
    conversation_data.to_json
  )
  
  if response && response.code.to_i < 400
    conversation = JSON.parse(response.body)
    log_result(:success, "Created conversation ID: #{conversation['id']}")
    return conversation['id']
  else
    log_result(:error, "Failed to create conversation: #{response&.code} - #{response&.body}")
    return nil
  end
end

def send_test_message(api_token, conversation_id)
  log_step("📤 STEP 5:", "Sending test message")
  
  message_data = {
    content: TEST_MESSAGE,
    message_type: 'outgoing'
  }
  
  response = make_api_request(
    'POST',
    "/api/v1/accounts/#{ACCOUNT_ID}/conversations/#{conversation_id}/messages",
    { 'api_access_token' => api_token },
    message_data.to_json
  )
  
  if response && response.code.to_i < 400
    message = JSON.parse(response.body)
    log_result(:success, "Sent message ID: #{message['id']}")
    log_result(:success, "Message content: #{TEST_MESSAGE}")
    return message['id']
  else
    log_result(:error, "Failed to send message: #{response&.code} - #{response&.body}")
    return nil
  end
end

def poll_for_message_via_api(api_token, conversation_id, message_id)
  log_step("⏰ STEP 6:", "Polling every #{POLL_INTERVAL}s for up to #{MAX_POLL_TIME}s to verify message appears in API")
  
  start_time = Time.now
  poll_count = 0
  
  while (Time.now - start_time) < MAX_POLL_TIME
    poll_count += 1
    current_time = Time.now - start_time
    
    log_step("🔍 POLL #{poll_count}:", "Checking if message appears in conversation (#{current_time.to_i}s elapsed)")
    
    # Get conversation messages
    response = make_api_request(
      'GET',
      "/api/v1/accounts/#{ACCOUNT_ID}/conversations/#{conversation_id}/messages",
      { 'api_access_token' => api_token }
    )
    
    if response && response.code == '200'
      data = JSON.parse(response.body)
      messages = data['payload'] || data['data'] || []
      
      # Look for our test message
      test_message = messages.find { |msg| msg['id'] == message_id }
      
      if test_message
        log_result(:success, "✅ Message found in API response!")
        log_result(:success, "  - Message ID: #{test_message['id']}")
        log_result(:success, "  - Content: #{test_message['content']}")
        log_result(:success, "  - Created: #{test_message['created_at']}")
        return true
      else
        log_result(:error, "❌ Message not found in API response")
        log_result(:error, "  - Total messages in conversation: #{messages.length}")
        log_result(:error, "  - Looking for message ID: #{message_id}")
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
  
  log_result(:error, "❌ TIMEOUT: Message not found in API within #{MAX_POLL_TIME}s")
  return false
end

def simulate_agent_checking_messages(api_token, conversation_id)
  log_step("👀 STEP 7:", "Simulating agent checking for new messages")
  
  # This simulates what an agent would do - check for new messages
  response = make_api_request(
    'GET',
    "/api/v1/accounts/#{ACCOUNT_ID}/conversations/#{conversation_id}/messages",
    { 'api_access_token' => api_token }
  )
  
  if response && response.code == '200'
    data = JSON.parse(response.body)
    messages = data['payload'] || data['data'] || []
    
    log_result(:success, "Agent can see #{messages.length} messages in conversation")
    
    # Find our test message
    test_message = messages.find { |msg| msg['content'] == TEST_MESSAGE }
    
    if test_message
      log_result(:success, "✅ Agent can see the test message!")
      log_result(:success, "  - Message: #{test_message['content']}")
      return true
    else
      log_result(:error, "❌ Agent cannot see the test message")
      return false
    end
  else
    log_result(:error, "Agent failed to get messages: #{response&.code}")
    return false
  end
end

def run_simplified_test
  puts "🚀 SIMPLIFIED WEBSOCKET POLLING TEST"
  puts "=" * 60
  puts "Testing: Message delivery and API polling simulation"
  puts "Inbox: #{INBOX_ID}"
  puts "Poll interval: #{POLL_INTERVAL}s"
  puts "Max poll time: #{MAX_POLL_TIME}s"
  puts "=" * 60
  
  begin
    # Step 1: Create test admin user
    user_info = create_test_admin_user
    return false unless user_info
    
    # Step 2: Get API token for user
    api_token = get_user_api_token(user_info[:email])
    return false unless api_token
    
    # Step 3: Check existing conversations
    conversations = get_inbox_conversations(api_token)
    
    # Step 4: Create test conversation
    conversation_id = create_test_conversation(api_token)
    return false unless conversation_id
    
    # Step 5: Send test message
    message_id = send_test_message(api_token, conversation_id)
    return false unless message_id
    
    # Step 6: Poll for message delivery via API
    message_found = poll_for_message_via_api(api_token, conversation_id, message_id)
    
    # Step 7: Simulate agent checking messages
    agent_can_see = simulate_agent_checking_messages(api_token, conversation_id)
    
    return message_found && agent_can_see
    
  rescue => e
    log_result(:error, "Test failed with exception: #{e.message}")
    log_result(:error, "Backtrace: #{e.backtrace.first(5).join("\n")}")
    return false
  end
end

# Run the test
if __FILE__ == $0
  success = run_simplified_test
  
  puts "\n" + "=" * 60
  if success
    puts "🎉 TEST PASSED: Message delivery and polling works!"
  else
    puts "❌ TEST FAILED: Message delivery or polling failed"
  end
  puts "=" * 60
  
  exit(success ? 0 : 1)
end 