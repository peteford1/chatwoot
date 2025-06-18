#!/usr/bin/env ruby

# Debug channel lookup issue
# Run with: bundle exec rails runner debug_channel_lookup.rb

puts "Debugging Twilio channel lookup..."

# Our webhook parameters
account_sid = 'ACtest123456789'
phone_number = '+19795412927'
messaging_service_sid = nil

puts "Looking for channel with:"
puts "  AccountSid: #{account_sid}"
puts "  To (phone_number): #{phone_number}"
puts "  MessagingServiceSid: #{messaging_service_sid}"
puts ""

# Check what channels exist
puts "Available channels:"
Channel::TwilioSms.all.each do |ch|
  puts "  ID: #{ch.id}"
  puts "  Phone: #{ch.phone_number.inspect}"
  puts "  Account SID: #{ch.account_sid.inspect}"
  puts "  Messaging Service SID: #{ch.messaging_service_sid.inspect}"
  puts ""
end

puts "Testing lookup logic..."

# First try messaging service lookup
puts "Step 1: messaging_service_sid lookup"
if messaging_service_sid.present?
  result = Channel::TwilioSms.find_by(messaging_service_sid: messaging_service_sid)
  puts "  Result: #{result.inspect}"
else
  puts "  Skipped (no messaging_service_sid)"
end

# Second try account_sid + phone_number lookup
puts "Step 2: account_sid + phone_number lookup"
if account_sid.present? && phone_number.present?
  puts "  Searching for: account_sid='#{account_sid}', phone_number='#{phone_number}'"
  
  # Try the exact query from the service
  begin
    result = Channel::TwilioSms.find_by!(account_sid: account_sid, phone_number: phone_number)
    puts "  ✅ Found: #{result.id}"
  rescue ActiveRecord::RecordNotFound => e
    puts "  ❌ Not found: #{e.message}"
    
    # Try without the ! to see if there's a match
    result = Channel::TwilioSms.find_by(account_sid: account_sid, phone_number: phone_number)
    puts "  Without !: #{result.inspect}"
    
    # Try manual conditions
    puts "  Manual search:"
    Channel::TwilioSms.where(account_sid: account_sid).each do |ch|
      puts "    Channel #{ch.id}: account_sid='#{ch.account_sid}', phone='#{ch.phone_number}'"
      puts "      Account SID match: #{ch.account_sid == account_sid}"
      puts "      Phone match: #{ch.phone_number == phone_number}"
    end
  end
else
  puts "  Skipped (missing account_sid or phone_number)"
end 