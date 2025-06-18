#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'

# Test script to simulate 3 Twilio webhook conversations
# Run with: bundle exec rails runner test_twilio_webhook.rb

puts "🚀 Simulating 3 Twilio webhook conversations..."
puts "From: +14353397687"
puts "To: +19795412927 (Account 1)"
puts "=" * 60

# Test messages for 3 different conversations
conversations = [
  {
    from: '+14353397687',
    messages: [
      "Hello! I'm interested in your services. Can you help me?",
      "I specifically need help with billing questions.",
      "When would be a good time to call?"
    ]
  },
  {
    from: '+14353397687', # Same sender, but will create different conversation due to different timestamps
    messages: [
      "Hi there! I'm having trouble with my account login.",
      "I've tried resetting my password but it's not working.",
      "Could you please assist me with this issue?"
    ]
  },
  {
    from: '+14353397687', # Same sender again
    messages: [
      "Good morning! I wanted to follow up on my previous inquiry.",
      "Has there been any update on the status of my request?",
      "I would appreciate any information you can provide."
    ]
  }
]

def simulate_twilio_webhook(from_number, to_number, message_body, conversation_index, message_index)
  # Generate unique IDs for each message
  sms_sid = "SM#{SecureRandom.hex(16)}"
  message_sid = "SM#{SecureRandom.hex(16)}"
  
  webhook_params = {
    'From' => from_number,
    'To' => to_number,
    'Body' => message_body,
    'AccountSid' => 'ACtest123456789',
    'SmsSid' => sms_sid,
    'MessageSid' => message_sid,
    'FromCountry' => 'US',
    'FromState' => 'CA',
    'FromCity' => 'SAN FRANCISCO',
    'FromZip' => '94105',
    'ToCountry' => 'US',
    'ToState' => 'TX',
    'ToCity' => 'HOUSTON',
    'ToZip' => '77001',
    'ApiVersion' => '2010-04-01'
  }

  puts "  📨 Sending message #{message_index + 1}: \"#{message_body}\""
  
  begin
    # Create the service and process the webhook
    service = Twilio::IncomingMessageService.new(params: webhook_params)
    service.perform
    
    puts "     ✅ Message processed successfully (SMS ID: #{sms_sid})"
    return true
  rescue => e
    puts "     ❌ Error processing message: #{e.message}"
    puts "     #{e.backtrace.first(3).join("\n     ")}"
    return false
  end
end

def resolve_existing_conversations(from_number)
  # Find the Twilio channel and inbox
  account = Account.first
  twilio_channel = Channel::TwilioSms.where(account: account).first
  return unless twilio_channel
  
  inbox = twilio_channel.inbox
  
  # Find any existing conversations for this contact
  contact = Contact.find_by(phone_number: from_number)
  return unless contact
  
  # Resolve all open conversations for this contact in this inbox
  conversations = inbox.conversations.where(contact: contact, status: ['open', 'pending'])
  conversations.each do |conv|
    conv.update!(status: 'resolved')
    puts "  🔄 Resolved conversation ##{conv.display_id} to allow new conversation"
  end
end

# Process each conversation
conversations.each_with_index do |conversation, conv_index|
  puts ""
  puts "🗣️  Conversation #{conv_index + 1}:"
  puts "From: #{conversation[:from]}"
  
  # Resolve existing conversations to force a new conversation
  if conv_index > 0
    resolve_existing_conversations(conversation[:from])
    sleep(1) # Give it a moment to process
  end
  
  conversation[:messages].each_with_index do |message, msg_index|
    success = simulate_twilio_webhook(
      conversation[:from],
      '+19795412927',
      message,
      conv_index,
      msg_index
    )
    
    # Add small delay between messages to ensure they're processed in order
    sleep(0.5) if success
  end
  
  # Add larger delay between conversations
  sleep(2) unless conv_index == conversations.length - 1
end

puts ""
puts "🎉 Webhook simulation complete!"
puts ""

# Verify the results
puts "📊 Verification:"
puts "-" * 40

begin
  account = Account.first
  twilio_channel = Channel::TwilioSms.where(account: account).first
  
  if twilio_channel
    inbox = twilio_channel.inbox
    recent_conversations = inbox.conversations.order(created_at: :desc).limit(10)
    
    puts "Account: #{account.name} (ID: #{account.id})"
    puts "Twilio Inbox: #{inbox.name} (ID: #{inbox.id})"
    puts "Total conversations: #{recent_conversations.count}"
    
    # Group by status
    open_convs = recent_conversations.select { |c| c.status == 'open' }
    resolved_convs = recent_conversations.select { |c| c.status == 'resolved' }
    
    puts "Open conversations: #{open_convs.count}"
    puts "Resolved conversations: #{resolved_convs.count}"
    puts ""
    
    recent_conversations.each_with_index do |conv, index|
      puts "Conversation #{index + 1}: ##{conv.display_id} (#{conv.status})"
      puts "  Contact: #{conv.contact.name} (#{conv.contact.phone_number})"
      puts "  Messages: #{conv.messages.count}"
      puts "  Created: #{conv.created_at.strftime('%Y-%m-%d %H:%M:%S')}"
      
      # Show latest message
      latest_message = conv.messages.last
      if latest_message
        puts "  Latest message: \"#{latest_message.content}\""
      end
      puts ""
    end
  else
    puts "❌ No Twilio channel found for verification"
  end
rescue => e
  puts "❌ Error during verification: #{e.message}"
end

puts ""
puts "🔗 You can view conversations in the Chatwoot dashboard:"
puts "   Local: http://localhost:8081/chatwoot-inbox-interface.html"
puts "   Azure: https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/" 