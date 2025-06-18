# WebSocket Multi-User Access Test Analysis
**Date**: 2025-06-13 12:40 UTC  
**Question**: Does the end-to-end test verify that all users assigned to an inbox can use their own token to read messages via WebSocket?  
**Status**: ❌ **NOT FULLY TESTED**

## 🔍 Analysis of Current Test Coverage

### ✅ **What IS Tested**

1. **ActionCable Message Broadcasting** (`spec/listeners/action_cable_listener_spec.rb`):
   ```ruby
   it 'sends message to account admins, inbox agents and the contact' do
     expect(ActionCableBroadcastJob).to receive(:perform_later).with(
       a_collection_containing_exactly(
         agent.pubsub_token,           # ← Inbox-assigned agent
         admin.pubsub_token,           # ← Account admin  
         conversation.contact_inbox.pubsub_token  # ← Contact
       ),
       'message.created',
       message.push_event_data.merge(account_id: account.id)
     )
   end
   ```

2. **WebSocket Channel Authentication** (`spec/channels/room_channel_spec.rb`):
   ```ruby
   it 'subscribes to a stream when pubsub_token is provided for user' do
     subscribe(user_id: user.id, pubsub_token: user.pubsub_token, account_id: account.id)
     expect(subscription).to be_confirmed
     expect(subscription).to have_stream_for(user.pubsub_token)
   end
   ```

3. **Inbox Member Access Control** (`spec/controllers/api/v1/accounts/inboxes_controller_spec.rb`):
   ```ruby
   it 'returns only assigned inboxes of current_account as agent' do
     # Agent only sees inboxes they're assigned to
   end
   ```

### ❌ **What is NOT Tested**

1. **Multiple Users with Same Inbox**: No test verifies that multiple agents assigned to the same inbox can all receive WebSocket messages
2. **Individual Token Verification**: No test confirms each user's unique `pubsub_token` works independently
3. **End-to-End WebSocket Flow**: No test that:
   - Creates multiple users
   - Assigns them all to the same inbox
   - Sends a message
   - Verifies each user receives the message via their own WebSocket connection

## 🧪 **Missing Test Scenario**

The comprehensive test should verify:

```ruby
describe 'Multiple users assigned to same inbox' do
  let(:inbox) { create(:inbox, account: account) }
  let(:agent1) { create(:user, account: account, role: :agent) }
  let(:agent2) { create(:user, account: account, role: :agent) }
  let(:agent3) { create(:user, account: account, role: :agent) }
  
  before do
    # Assign all 3 agents to the same inbox
    create(:inbox_member, inbox: inbox, user: agent1)
    create(:inbox_member, inbox: inbox, user: agent2) 
    create(:inbox_member, inbox: inbox, user: agent3)
  end
  
  it 'sends messages to all assigned agents via their individual pubsub_tokens' do
    conversation = create(:conversation, inbox: inbox, account: account)
    message = create(:message, conversation: conversation, inbox: inbox)
    
    # Should broadcast to ALL 3 agents + admin + contact
    expect(ActionCableBroadcastJob).to receive(:perform_later).with(
      a_collection_containing_exactly(
        agent1.pubsub_token,  # ← Each agent gets their own token
        agent2.pubsub_token,  # ← Each agent gets their own token  
        agent3.pubsub_token,  # ← Each agent gets their own token
        admin.pubsub_token,
        conversation.contact_inbox.pubsub_token
      ),
      'message.created',
      message.push_event_data.merge(account_id: account.id)
    )
  end
  
  it 'allows each agent to connect via WebSocket with their own token' do
    # Test that each agent can establish WebSocket connection
    # and receive messages independently
  end
end
```

## 📋 **Current Test Limitations**

1. **Single Agent Tests**: Most tests only create 1 agent per inbox
2. **No Multi-User WebSocket**: No tests verify multiple WebSocket connections to same inbox
3. **No Token Isolation**: No verification that each user's token works independently
4. **No Real WebSocket**: Tests mock `ActionCableBroadcastJob` but don't test actual WebSocket delivery

## ✅ **What We Know Works (From Code Analysis)**

1. **ActionCableListener.user_tokens()** method correctly collects all inbox member tokens:
   ```ruby
   def user_tokens(account, agents)
     agent_tokens = agents.pluck(:pubsub_token)      # ← All assigned agents
     admin_tokens = account.administrators.pluck(:pubsub_token)  # ← All admins
     (agent_tokens + admin_tokens).uniq
   end
   ```

2. **RoomChannel** authenticates users by their individual `pubsub_token`:
   ```ruby
   def current_user
     User.find_by!(pubsub_token: pubsub_token, id: params[:user_id])
   end
   ```

## 🎯 **Recommendation**

**Create a comprehensive multi-user WebSocket test** that:
1. Creates multiple agents assigned to same inbox
2. Establishes WebSocket connections for each agent using their individual tokens
3. Sends a message and verifies all agents receive it
4. Confirms token isolation (Agent A can't use Agent B's token)

This would provide complete confidence in the multi-user WebSocket functionality. 