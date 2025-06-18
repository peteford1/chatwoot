#!/usr/bin/env ruby

# Debug Twilio webhook processing step by step
# Run with: bundle exec rails runner debug_webhook.rb

puts "Debugging Twilio webhook processing..."

# Webhook parameters
webhook_params = {
  'From' => '+14353397687',
  'To' => '+19795412927', 
  'Body' => 'Debug test message for +19795412927.',
  'AccountSid' => 'ACtest123456789',
  'SmsSid' => 'SM' + SecureRandom.hex(16),
  'MessageSid' => 'SM' + SecureRandom.hex(16),
  'FromCountry' => 'US',
  'FromState' => 'TX',
  'FromCity' => 'DALLAS',
  'FromZip' => '75201',
  'ToCountry' => 'US',
  'ToState' => 'TX',
  'ToCity' => 'HOUSTON',
  'ToZip' => '77001',
  'ApiVersion' => '2010-04-01'
}

puts "Webhook params:"
webhook_params.each { |k, v| puts "  #{k}: #{v}" }
puts ""

begin
  puts "Step 1: Creating service..."
  service = Twilio::IncomingMessageService.new(params: webhook_params)
  
  puts "Step 2: Finding Twilio channel..."
  # Access private method for debugging
  twilio_channel = service.send(:twilio_channel)
  
  if twilio_channel
    puts "✅ Found Twilio channel: #{twilio_channel.id}"
    puts "   Phone: #{twilio_channel.phone_number}"
    puts "   Account SID: #{twilio_channel.account_sid}"
    
    inbox = service.send(:inbox)
    puts "✅ Found inbox: #{inbox.name} (ID: #{inbox.id})"
    
    account = service.send(:account)
    puts "✅ Found account: #{account.name} (ID: #{account.id})"
  else
    puts "❌ No Twilio channel found!"
    puts ""
    puts "Available Twilio channels:"
    Channel::TwilioSms.all.each do |ch|
      puts "  ID: #{ch.id}, Phone: #{ch.phone_number}, Account SID: #{ch.account_sid}"
    end
    exit 1
  end
  
  puts ""
  puts "Step 3: Testing contact creation..."
  phone_number = service.send(:phone_number)
  puts "Phone number: #{phone_number}"
  
  formatted_phone = service.send(:formatted_phone_number)
  puts "Formatted phone: #{formatted_phone}"
  
  # Check if contact already exists
  existing_contact = account.contacts.find_by(phone_number: phone_number)
  if existing_contact
    puts "Contact already exists: #{existing_contact.name}"
  else
    puts "No existing contact found"
  end
  
  puts ""
  puts "Step 4: Running full service..."
  
  # Count before
  conv_count_before = inbox.conversations.count
  msg_count_before = Message.count
  contact_count_before = account.contacts.count
  
  puts "Before: #{conv_count_before} conversations, #{msg_count_before} messages, #{contact_count_before} contacts"
  
  service.perform
  
  # Count after
  conv_count_after = inbox.conversations.count
  msg_count_after = Message.count
  contact_count_after = account.contacts.count
  
  puts "After: #{conv_count_after} conversations, #{msg_count_after} messages, #{contact_count_after} contacts"
  
  if conv_count_after > conv_count_before
    puts "✅ New conversation created!"
    conversation = inbox.conversations.order(created_at: :desc).first
    puts "   Conversation ##{conversation.display_id}"
    puts "   Contact: #{conversation.contact.name} (#{conversation.contact.phone_number})"
    puts "   Messages: #{conversation.messages.count}"
  else
    puts "❌ No new conversation created"
  end

rescue => e
  puts "❌ ERROR: #{e.message}"
  puts "Stack trace:"
  puts e.backtrace.first(10).join("\n")
end 