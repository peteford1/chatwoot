#!/usr/bin/env ruby

# Verification script to check if the test message was created
# Run with: bundle exec rails runner verify_test_message.rb

puts "Verifying test message creation..."
puts ""

# Find the test account
account = Account.first
puts "Account: #{account.name} (ID: #{account.id})"

# Find the Twilio channel directly
twilio_channel = Channel::TwilioSms.where(account: account).first
if twilio_channel
  puts "Twilio Channel Phone: #{twilio_channel.phone_number}"
  puts "Channel Account SID: #{twilio_channel.account_sid}"
  
  # Find the inbox for this channel
  twilio_inbox = twilio_channel.inbox
  puts "Twilio Inbox: #{twilio_inbox.name} (ID: #{twilio_inbox.id})"
else
  puts "❌ No Twilio channel found!"
  exit 1
end

puts ""

# Look for conversations in the Twilio inbox
conversations = twilio_inbox.conversations.order(created_at: :desc).limit(5)
puts "Recent conversations in Twilio inbox:"

if conversations.any?
  conversations.each do |conv|
    contact = conv.contact
    puts ""
    puts "Conversation ##{conv.display_id}"
    puts "  Contact: #{contact.name} (#{contact.phone_number})"
    puts "  Status: #{conv.status}"
    puts "  Created: #{conv.created_at}"
    puts "  Messages: #{conv.messages.count}"
    
    # Show recent messages
    conv.messages.order(created_at: :desc).limit(3).each do |msg|
      sender = msg.sender ? "#{msg.sender.name}" : "Contact"
      content = msg.content || "[No content]"
      puts "    #{msg.created_at.strftime('%H:%M')} [#{msg.message_type}] #{sender}: #{content.truncate(50)}"
    end
  end
  
  puts ""
  puts "✅ SUCCESS: Found #{conversations.count} conversation(s) in the Twilio inbox!"
  
  # Check for our test message specifically
  test_message = Message.joins(:conversation)
                        .where(conversations: { inbox_id: twilio_inbox.id })
                        .where("messages.content LIKE ?", "%Testing phone number +19795412927%")
                        .first
  
  if test_message
    puts "✅ Found our test message!"
    puts "   Message ID: #{test_message.id}"
    puts "   Content: #{test_message.content}"
    puts "   Sender: #{test_message.sender&.name || 'Contact'}"
    puts "   From: #{test_message.conversation.contact.phone_number}"
  else
    puts "⚠️  Test message not found, checking for any recent messages..."
    
    # Check for any recent message from our test phone number
    recent_message = Message.joins(:conversation => :contact)
                           .where(conversations: { inbox_id: twilio_inbox.id })
                           .where(contacts: { phone_number: '+14353397687' })
                           .order(created_at: :desc)
                           .first
    
    if recent_message
      puts "   Found message from +14353397687: #{recent_message.content}"
    else
      puts "   No messages found from +14353397687"
    end
  end
  
else
  puts "❌ No conversations found in the Twilio inbox."
  puts "The webhook may not have been processed correctly."
end

puts ""
puts "Dashboard URL:"
puts "https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/app/accounts/#{account.id}/dashboard" 