#!/usr/bin/env ruby

# Manual test of Twilio webhook processing
# Run with: bundle exec rails runner test_manual_webhook.rb

puts "Testing Twilio webhook processing manually..."

# Webhook parameters that would come from Twilio (using symbol keys)
webhook_params = {
  From: '+14353397687',
  To: '+19795412927', 
  Body: 'Hello! This is a manual test message for phone number +19795412927.',
  AccountSid: 'ACtest123456789',
  SmsSid: 'SM' + SecureRandom.hex(16),
  MessageSid: 'SM' + SecureRandom.hex(16),
  FromCountry: 'US',
  FromState: 'TX',
  FromCity: 'DALLAS',
  FromZip: '75201',
  ToCountry: 'US',
  ToState: 'TX',
  ToCity: 'HOUSTON',
  ToZip: '77001',
  ApiVersion: '2010-04-01'
}

puts "Webhook params:"
webhook_params.each { |k, v| puts "  #{k}: #{v}" }
puts ""

begin
  # Test the incoming message service directly
  puts "Testing Twilio::IncomingMessageService..."
  service = Twilio::IncomingMessageService.new(params: webhook_params)
  
  puts "Running service.perform..."
  service.perform
  
  puts "✅ SUCCESS: Webhook processed successfully!"
  
  # Verify the message was created
  puts ""
  puts "Verifying message creation..."
  
  # Find the account and inbox
  account = Account.first
  twilio_channel = Channel::TwilioSms.where(account: account).first
  twilio_inbox = twilio_channel.inbox
  
  # Look for the conversation
  conversation = twilio_inbox.conversations.order(created_at: :desc).first
  
  if conversation
    puts "✅ Conversation created: ##{conversation.display_id}"
    puts "   Contact: #{conversation.contact.name} (#{conversation.contact.phone_number})"
    puts "   Messages: #{conversation.messages.count}"
    
    conversation.messages.each do |msg|
      puts "   - #{msg.content}"
    end
  else
    puts "❌ No conversation found"
  end

rescue => e
  puts "❌ ERROR: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end

puts ""
puts "Dashboard URL:"
puts "https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/app/accounts/1/dashboard" 