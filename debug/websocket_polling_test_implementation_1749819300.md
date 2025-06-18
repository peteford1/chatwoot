# WebSocket Multi-User Polling Test Implementation
**Date**: 2025-06-13 12:55 UTC  
**Purpose**: Test that all users assigned to an inbox can receive messages via their individual WebSocket tokens  
**Polling Strategy**: Check every 20 seconds for up to 5 minutes  

## 🎯 **Test Objective**

Verify that when a reply is sent to a conversation:
1. **All agents assigned to the inbox** receive the message via their individual WebSocket connections
2. **Each agent uses their own unique `pubsub_token`** for authentication
3. **Message delivery is confirmed within 5 minutes** using 20-second polling intervals
4. **No agent is left out** of the message distribution

## 🏗️ **Test Architecture**

### **Step 1: Setup Multiple WebSocket Connections**
```ruby
def create_websocket_connections(agents)
  agents.each do |agent|
    ws = WebSocket::Client::Simple.connect(WS_BASE)
    
    ws.on :open do
      # Subscribe to RoomChannel with individual token
      subscribe_message = {
        command: 'subscribe',
        identifier: JSON.stringify({
          channel: 'RoomChannel',
          pubsub_token: agent[:pubsub_token],  # ← Individual token
          user_id: agent[:id],
          account_id: ACCOUNT_ID
        })
      }
      ws.send(subscribe_message.to_json)
    end
    
    ws.on :message do |event|
      # Track which agents receive the message
      if message_matches_test_message(event.data)
        $message_received_by << agent[:name]
      end
    end
  end
end
```

### **Step 2: Send Test Reply**
```ruby
def send_test_reply(conversation_id)
  message_data = {
    content: "Test reply - #{Time.now.to_i}",
    message_type: 'outgoing'
  }
  
  # Send via API - this triggers ActionCable broadcast
  POST "/api/v1/accounts/#{ACCOUNT_ID}/conversations/#{conversation_id}/messages"
end
```

### **Step 3: Poll Every 20 Seconds for 5 Minutes**
```ruby
def poll_for_message_delivery(expected_agents)
  start_time = Time.now
  poll_count = 0
  
  while (Time.now - start_time) < 300  # 5 minutes
    poll_count += 1
    current_time = Time.now - start_time
    
    puts "POLL #{poll_count}: Checking delivery (#{current_time.to_i}s elapsed)"
    
    received_count = $message_received_by.length
    total_expected = expected_agents.length
    
    puts "Message received by #{received_count}/#{total_expected} agents"
    
    # Show status for each agent
    expected_agents.each do |agent|
      if $message_received_by.include?(agent[:name])
        puts "  ✓ #{agent[:name]} - Message received via WebSocket"
      else
        puts "  ✗ #{agent[:name]} - Waiting for message..."
      end
    end
    
    # Success condition
    if received_count >= total_expected
      puts "🎉 ALL AGENTS RECEIVED THE MESSAGE!"
      return true
    end
    
    # Wait 20 seconds for next poll
    sleep(20) if (Time.now - start_time) < 300
  end
  
  puts "❌ TIMEOUT: Not all agents received message within 5 minutes"
  return false
end
```

## 📊 **Expected Test Flow**

### **Timeline Example:**
```
00:00 - Test starts, WebSocket connections established
00:05 - Test message sent via API
00:05 - ActionCable broadcasts to all agent tokens
00:20 - POLL 1: Check which agents received message
00:40 - POLL 2: Check again (some agents may receive delayed)
01:00 - POLL 3: Continue checking
01:20 - POLL 4: Most agents should have received by now
...
05:00 - POLL 15: Final check before timeout
```

### **Success Criteria:**
- ✅ All assigned agents receive the message within 5 minutes
- ✅ Each agent receives via their individual `pubsub_token`
- ✅ Message content matches exactly
- ✅ No authentication errors

### **Failure Scenarios:**
- ❌ Some agents never receive the message (WebSocket issue)
- ❌ Authentication fails for some tokens (token issue)
- ❌ Message content doesn't match (broadcast issue)
- ❌ Timeout after 5 minutes (system performance issue)

## 🔧 **Implementation Files Created**

1. **`comprehensive_websocket_multi_user_test.rb`**
   - Full WebSocket implementation with real connections
   - Requires valid API tokens
   - Tests actual Chatwoot system

2. **`demo_polling_test.rb`**
   - Demonstration of polling logic
   - Simulated agents and message delivery
   - Shows expected test flow and timing

## 🎯 **Key Testing Points**

### **Multi-User WebSocket Verification:**
```ruby
# Verify each agent gets their own WebSocket stream
agents.each do |agent|
  expect(subscription).to have_stream_for(agent.pubsub_token)
end

# Verify ActionCable broadcasts to all agent tokens
expect(ActionCableBroadcastJob).to receive(:perform_later).with(
  a_collection_containing_exactly(
    agent1.pubsub_token,  # ← Individual tokens
    agent2.pubsub_token,  # ← Individual tokens
    agent3.pubsub_token,  # ← Individual tokens
    admin.pubsub_token,
    contact_inbox.pubsub_token
  ),
  'message.created',
  message.push_event_data
)
```

### **Token Isolation Testing:**
```ruby
# Verify Agent A cannot use Agent B's token
expect {
  subscribe(user_id: agent_a.id, pubsub_token: agent_b.pubsub_token)
}.to raise_error(ActiveRecord::RecordNotFound)
```

## 📋 **Current Test Gap Analysis**

### ❌ **Missing from Current Test Suite:**
1. **No multi-agent WebSocket tests** - Only single agent scenarios
2. **No polling verification** - Tests are synchronous
3. **No token isolation tests** - No verification that tokens are user-specific
4. **No end-to-end WebSocket flow** - Tests mock ActionCable instead of real WebSocket

### ✅ **What Currently Works:**
1. **ActionCable broadcasting logic** - Correctly sends to all inbox members
2. **Individual WebSocket authentication** - RoomChannel validates tokens
3. **Inbox access control** - Agents only see assigned inboxes

## 🚀 **Recommended Implementation**

To fully test multi-user WebSocket functionality:

1. **Add the comprehensive test** to the test suite
2. **Run during CI/CD** to catch WebSocket regressions
3. **Monitor polling results** to identify performance issues
4. **Test with varying agent counts** (1, 3, 5, 10+ agents)
5. **Test edge cases** like agents joining/leaving during message sending

## 💡 **Real-World Benefits**

This test ensures:
- **Customer support teams** can collaborate effectively
- **No missed messages** when multiple agents handle the same inbox
- **Real-time updates** work for all team members
- **Scalability** as teams grow and add more agents
- **Reliability** of the WebSocket infrastructure

The 20-second polling with 5-minute timeout provides a good balance between:
- **Responsiveness** - Catches issues quickly
- **Reliability** - Allows for network delays and system load
- **Practicality** - Reasonable test execution time 