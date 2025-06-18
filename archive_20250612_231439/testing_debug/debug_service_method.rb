#!/usr/bin/env ruby

# Debug the service's twilio_channel method specifically
# Run with: bundle exec rails runner debug_service_method.rb

puts "Debugging service twilio_channel method..."

# Webhook parameters exactly as they come from our test
webhook_params = {
  'From' => '+14353397687',
  'To' => '+19795412927', 
  'Body' => 'Debug test message.',
  'AccountSid' => 'ACtest123456789',
  'SmsSid' => 'SM123456789',
  'MessageSid' => 'SM987654321',
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

# Create service
service = Twilio::IncomingMessageService.new(params: webhook_params)

# Debug the internal logic step by step
puts "Debugging twilio_channel method logic..."

# Check messaging service sid first
messaging_service_sid = webhook_params['MessagingServiceSid']
puts "MessagingServiceSid: #{messaging_service_sid.inspect}"
puts "MessagingServiceSid.present?: #{messaging_service_sid.present?}"

if messaging_service_sid.present?
  result = Channel::TwilioSms.find_by(messaging_service_sid: messaging_service_sid)
  puts "Found by messaging_service_sid: #{result.inspect}"
else
  puts "Skipping messaging_service_sid lookup"
end

# Check account_sid + phone_number
account_sid = webhook_params['AccountSid']
phone_number = webhook_params['To']
puts ""
puts "AccountSid: #{account_sid.inspect}"
puts "To (phone_number): #{phone_number.inspect}"
puts "AccountSid.present?: #{account_sid.present?}"
puts "To.present?: #{phone_number.present?}"

if account_sid.present? && phone_number.present?
  puts "Attempting find_by!(account_sid: #{account_sid}, phone_number: #{phone_number})"
  begin
    result = Channel::TwilioSms.find_by!(account_sid: account_sid, phone_number: phone_number)
    puts "✅ Found by account_sid+phone: #{result.inspect}"
  rescue => e
    puts "❌ Error in find_by!: #{e.class} - #{e.message}"
  end
else
  puts "Skipping account_sid+phone lookup"
end

puts ""
puts "Now testing the actual service method..."
begin
  channel = service.send(:twilio_channel)
  puts "Service twilio_channel result: #{channel.inspect}"
  if channel
    puts "✅ Service found channel: #{channel.id}"
  else
    puts "❌ Service returned nil"
  end
rescue => e
  puts "❌ Service method error: #{e.class} - #{e.message}"
  puts "Stack trace:"
  puts e.backtrace.first(5).join("\n")
end 