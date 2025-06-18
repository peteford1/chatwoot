#!/usr/bin/env ruby

# Debug script for Twilio webhook processing
# Run with: rails runner debug_twilio_webhook.rb

def debug_webhook_processing
  puts "Starting Twilio webhook debug..."
  
  # Test parameters
  params = {
    'From' => '+12025550142',
    'To' => '+19795412927',
    'Body' => 'Test message from debug script',
    'AccountSid' => 'ACtest123456789',
    'SmsSid' => 'SM123test',
    'MessageSid' => 'MM123test'
  }
  
  puts "\n1. Looking up Twilio channel..."
  channel = Channel::TwilioSms.find_by(account_sid: params['AccountSid'], phone_number: params['To'])
  if channel
    puts "✓ Found channel: #{channel.id}"
    puts "  - Phone number: #{channel.phone_number}"
    puts "  - Account SID: #{channel.account_sid}"
  else
    puts "❌ Channel not found!"
    return
  end
  
  puts "\n2. Getting inbox..."
  inbox = channel.inbox
  if inbox
    puts "✓ Found inbox: #{inbox.id}"
    puts "  - Name: #{inbox.name}"
  else
    puts "❌ Inbox not found!"
    return
  end
  
  # Override Redis for this test
  $alfred = ConnectionPool.new(size: 1, timeout: 1) { Redis.new(url: 'redis://127.0.0.1:6379') }
  puts "✓ Overriding Redis connection for this test"

  puts "\n3. Creating/finding contact..."
  begin
    contact_builder = ContactInboxWithContactBuilder.new(
      source_id: params['From'],
      inbox: inbox,
      contact_attributes: {
        name: params['From'],
        phone_number: params['From']
      }
    )
    contact_inbox = contact_builder.perform
    puts "✓ Contact inbox created/found"
    puts "  - Contact ID: #{contact_inbox.contact.id}"
    puts "  - Phone: #{contact_inbox.contact.phone_number}"
  rescue => e
    puts "❌ Error creating contact: #{e.message}"
    return
  end
  
  puts "\n4. Creating conversation..."
  begin
    conversation = contact_inbox.conversations.where.not(status: :resolved).last
    if conversation.nil?
      conversation = Conversation.create!(
        account_id: inbox.account_id,
        inbox_id: inbox.id,
        contact_id: contact_inbox.contact.id,
        contact_inbox_id: contact_inbox.id
      )
      puts "✓ New conversation created: #{conversation.id}"
    else
      puts "✓ Using existing conversation: #{conversation.id}"
    end
  rescue => e
    puts "❌ Error creating conversation: #{e.message}"
    return
  end
  
  puts "\n5. Creating message..."
  begin
    message = conversation.messages.create!(
      content: params['Body'],
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      message_type: :incoming,
      sender: contact_inbox.contact,
      source_id: params['SmsSid']
    )
    puts "✓ Message created successfully!"
    puts "  - Content: #{message.content}"
    puts "  - Type: #{message.message_type}"
    puts "  - Source ID: #{message.source_id}"
  rescue => e
    puts "❌ Error creating message: #{e.message}"
    return
  end
  
  puts "\nDebug completed successfully! 🎉"
end

# Run the debug process
debug_webhook_processing 