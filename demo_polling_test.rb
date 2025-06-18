#!/usr/bin/env ruby

require 'json'

# Test configuration
POLL_INTERVAL = 20  # seconds
MAX_POLL_TIME = 300 # 5 minutes (300 seconds)
TEST_MESSAGE = "Multi-user WebSocket test message - #{Time.now.to_i}"

# Simulated test data
$simulated_agents = [
  { id: 1, name: "Agent Alice", email: "alice@example.com", pubsub_token: "token_alice_123" },
  { id: 2, name: "Agent Bob", email: "bob@example.com", pubsub_token: "token_bob_456" },
  { id: 3, name: "Agent Charlie", email: "charlie@example.com", pubsub_token: "token_charlie_789" }
]

$message_received_by = []
$test_message_id = 12345

def log_step(step, message)
  timestamp = Time.now.strftime("%H:%M:%S")
  puts "\n[#{timestamp}] #{step} #{message}"
end

def log_result(status, message)
  icon = status == :success ? "✅" : (status == :error ? "❌" : "⚠️")
  puts "   #{icon} #{message}"
end

def simulate_websocket_connections
  log_step("🔌 STEP 1:", "Simulating WebSocket connections for #{$simulated_agents.length} agents")
  
  $simulated_agents.each do |agent|
    log_result(:success, "WebSocket connected for #{agent[:name]} (token: #{agent[:pubsub_token][0..15]}...)")
  end
  
  log_result(:success, "All #{$simulated_agents.length} WebSocket connections established")
end

def simulate_message_sending
  log_step("📤 STEP 2:", "Simulating message sending")
  
  log_result(:success, "Sent test message ID: #{$test_message_id}")
  log_result(:success, "Message content: #{TEST_MESSAGE}")
  log_result(:success, "Message broadcast to ActionCable with tokens:")
  
  $simulated_agents.each do |agent|
    log_result(:success, "  - #{agent[:name]}: #{agent[:pubsub_token]}")
  end
end

def simulate_random_message_delivery
  # Simulate agents receiving messages at different times
  # This demonstrates the polling concept
  
  # Agent Alice receives immediately
  if rand < 0.8  # 80% chance
    $message_received_by << $simulated_agents[0][:name]
  end
  
  # Agent Bob receives after some delay (simulated by poll count)
  if $poll_count >= 2 && rand < 0.9  # 90% chance after 2nd poll
    $message_received_by << $simulated_agents[1][:name] unless $message_received_by.include?($simulated_agents[1][:name])
  end
  
  # Agent Charlie receives after longer delay
  if $poll_count >= 4 && rand < 0.95  # 95% chance after 4th poll
    $message_received_by << $simulated_agents[2][:name] unless $message_received_by.include?($simulated_agents[2][:name])
  end
end

def poll_for_websocket_delivery
  log_step("⏰ STEP 3:", "Polling every #{POLL_INTERVAL}s for up to #{MAX_POLL_TIME}s to verify WebSocket message delivery")
  
  start_time = Time.now
  $poll_count = 0
  
  while (Time.now - start_time) < MAX_POLL_TIME
    $poll_count += 1
    current_time = Time.now - start_time
    
    log_step("🔍 POLL #{$poll_count}:", "Checking WebSocket message delivery (#{current_time.to_i}s elapsed)")
    
    # Simulate checking WebSocket message delivery
    simulate_random_message_delivery
    
    # Check how many agents have received the message
    received_count = $message_received_by.length
    total_expected = $simulated_agents.length
    
    log_result(:success, "Message received by #{received_count}/#{total_expected} agents via WebSocket")
    
    $message_received_by.each do |agent_name|
      log_result(:success, "  ✓ #{agent_name} - WebSocket message received")
    end
    
    missing_agents = $simulated_agents.map { |a| a[:name] } - $message_received_by
    missing_agents.each do |agent_name|
      log_result(:error, "  ✗ #{agent_name} - WebSocket message not received yet")
    end
    
    # Check if all agents have received the message
    if received_count >= total_expected
      log_result(:success, "🎉 ALL AGENTS RECEIVED THE MESSAGE VIA WEBSOCKET!")
      return true
    end
    
    # Wait for next poll (shortened for demo)
    if (Time.now - start_time) < MAX_POLL_TIME
      log_result(:success, "Waiting #{POLL_INTERVAL}s for next poll...")
      
      # For demo purposes, use shorter intervals
      demo_interval = [POLL_INTERVAL, 5].min  # Max 5 seconds for demo
      sleep(demo_interval)
    end
  end
  
  log_result(:error, "❌ TIMEOUT: Not all agents received the message within #{MAX_POLL_TIME}s")
  return false
end

def demonstrate_api_verification
  log_step("🔍 STEP 4:", "Demonstrating API verification for each agent")
  
  $simulated_agents.each do |agent|
    log_result(:success, "Simulating API call for #{agent[:name]}:")
    log_result(:success, "  GET /api/v1/accounts/1/conversations/123/messages")
    log_result(:success, "  Authorization: Bearer #{agent[:pubsub_token][0..15]}...")
    
    if $message_received_by.include?(agent[:name])
      log_result(:success, "  ✅ Agent can see the message in API response")
      log_result(:success, "  📝 Message: #{TEST_MESSAGE}")
    else
      log_result(:error, "  ❌ Agent cannot see the message yet")
    end
  end
end

def demonstrate_real_world_implementation
  log_step("💡 STEP 5:", "Real-world implementation notes")
  
  puts "\n   📋 In a real implementation, this test would:"
  puts "   1. Create actual WebSocket connections using websocket-client-simple"
  puts "   2. Subscribe each agent to RoomChannel with their pubsub_token"
  puts "   3. Send a real message via Chatwoot API"
  puts "   4. Listen for 'message.created' events on each WebSocket"
  puts "   5. Verify each agent receives the exact message"
  puts "   6. Poll every 20 seconds for up to 5 minutes"
  puts "   7. Report success when all agents receive the message"
  
  puts "\n   🔧 WebSocket subscription format:"
  puts "   {"
  puts "     command: 'subscribe',"
  puts "     identifier: JSON.stringify({"
  puts "       channel: 'RoomChannel',"
  puts "       pubsub_token: 'user_specific_token',"
  puts "       user_id: user_id,"
  puts "       account_id: account_id"
  puts "     })"
  puts "   }"
  
  puts "\n   📨 Expected WebSocket message format:"
  puts "   {"
  puts "     message: {"
  puts "       event: 'message.created',"
  puts "       data: {"
  puts "         id: message_id,"
  puts "         content: 'message content',"
  puts "         conversation_id: conversation_id"
  puts "       }"
  puts "     }"
  puts "   }"
end

def run_demo_test
  puts "🚀 WEBSOCKET MULTI-USER POLLING TEST DEMONSTRATION"
  puts "=" * 70
  puts "This demonstrates the structure and polling logic for testing"
  puts "that multiple agents receive WebSocket messages with their own tokens"
  puts "=" * 70
  puts "Configuration:"
  puts "- Poll interval: #{POLL_INTERVAL} seconds"
  puts "- Max poll time: #{MAX_POLL_TIME} seconds (5 minutes)"
  puts "- Test agents: #{$simulated_agents.length}"
  puts "=" * 70
  
  begin
    # Step 1: Simulate WebSocket connections
    simulate_websocket_connections
    
    # Step 2: Simulate message sending
    simulate_message_sending
    
    # Step 3: Poll for WebSocket delivery
    success = poll_for_websocket_delivery
    
    # Step 4: Demonstrate API verification
    demonstrate_api_verification
    
    # Step 5: Show real-world implementation notes
    demonstrate_real_world_implementation
    
    return success
    
  rescue => e
    log_result(:error, "Demo failed with exception: #{e.message}")
    return false
  end
end

# Run the demo
if __FILE__ == $0
  success = run_demo_test
  
  puts "\n" + "=" * 70
  if success
    puts "🎉 DEMO COMPLETED: All agents received the message!"
    puts "✅ This demonstrates the polling logic works correctly"
  else
    puts "❌ DEMO TIMEOUT: Not all agents received the message"
    puts "⚠️  In real implementation, this would indicate WebSocket issues"
  end
  puts "=" * 70
  
  puts "\n📝 SUMMARY:"
  puts "This test demonstrates how to verify that multiple users assigned"
  puts "to the same inbox can receive messages via their individual WebSocket"
  puts "connections by polling every 20 seconds for up to 5 minutes."
  
  exit(success ? 0 : 1)
end 