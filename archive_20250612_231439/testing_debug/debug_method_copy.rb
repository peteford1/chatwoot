#!/usr/bin/env ruby

# Debug the exact twilio_channel method logic
# Run with: bundle exec rails runner debug_method_copy.rb

puts "Debugging exact twilio_channel method logic..."

# Webhook parameters
params = {
  'From' => '+14353397687',
  'To' => '+19795412927', 
  'Body' => 'Debug test message.',
  'AccountSid' => 'ACtest123456789',
  'SmsSid' => 'SM123456789',
  'MessageSid' => 'SM987654321',
  'MessagingServiceSid' => nil
}

puts "Params:"
params.each { |k, v| puts "  #{k}: #{v.inspect}" }
puts ""

# Copy the exact logic from the service
puts "Executing exact service logic..."

# Initialize the instance variable
@twilio_channel = nil

# First part: messaging service lookup
puts "Step 1: Messaging service lookup"
if params['MessagingServiceSid'].present?
  puts "  MessagingServiceSid is present: #{params['MessagingServiceSid']}"
  @twilio_channel = Channel::TwilioSms.find_by(messaging_service_sid: params['MessagingServiceSid'])
  puts "  Result: #{@twilio_channel.inspect}"
else
  puts "  MessagingServiceSid not present, skipping"
end

# Second part: account_sid + phone_number lookup
puts ""
puts "Step 2: Account SID + Phone lookup"
puts "  AccountSid present?: #{params['AccountSid'].present?}"
puts "  To present?: #{params['To'].present?}"

if params['AccountSid'].present? && params['To'].present?
  puts "  Both present, executing find_by!"
  begin
    # This is the exact line from the service
    @twilio_channel ||= Channel::TwilioSms.find_by!(account_sid: params['AccountSid'], phone_number: params['To'])
    puts "  find_by! result: #{@twilio_channel.inspect}"
  rescue => e
    puts "  find_by! error: #{e.class} - #{e.message}"
  end
else
  puts "  Conditions not met, skipping"
end

# Final result
puts ""
puts "Final @twilio_channel: #{@twilio_channel.inspect}"

# Test without the ||= to see if that's the issue
puts ""
puts "Testing without ||= operator..."
test_channel = Channel::TwilioSms.find_by!(account_sid: params['AccountSid'], phone_number: params['To'])
puts "Direct find_by! result: #{test_channel.inspect}"

# Test with ||= but starting with nil
puts ""
puts "Testing ||= with explicit nil..."
test_var = nil
test_var ||= Channel::TwilioSms.find_by!(account_sid: params['AccountSid'], phone_number: params['To'])
puts "||= result: #{test_var.inspect}" 