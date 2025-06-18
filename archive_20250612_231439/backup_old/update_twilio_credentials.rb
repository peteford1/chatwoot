#!/usr/bin/env ruby

# Update Twilio channel credentials with real values
# Run with: bundle exec rails runner update_twilio_credentials.rb

puts "🔧 Updating Twilio channel credentials..."

# Find the existing Twilio channel
account = Account.first
twilio_channel = Channel::TwilioSms.where(account: account).first

if twilio_channel.nil?
  puts "❌ No Twilio channel found!"
  exit 1
end

puts "Found Twilio channel: #{twilio_channel.phone_number}"
puts "Current Account SID: #{twilio_channel.account_sid}"
puts ""

# Update with your real Twilio credentials
# You need to replace these with your actual Twilio values:
puts "⚠️  IMPORTANT: Update these with your real Twilio credentials:"
puts ""
puts "twilio_channel.update!("
puts "  account_sid: 'AC...your_real_account_sid...',"
puts "  auth_token: 'your_real_auth_token'"
puts ")"
puts ""
puts "To get your Twilio credentials:"
puts "1. Go to https://console.twilio.com/"
puts "2. Get your Account SID and Auth Token from the dashboard"
puts "3. Make sure your phone number +19795412927 is registered with your Twilio account"
puts ""

# Uncomment and update these lines with your real credentials:
# twilio_channel.update!(
#   account_sid: 'AC...your_real_account_sid...',
#   auth_token: 'your_real_auth_token'
# )
# puts "✅ Twilio credentials updated successfully!"

puts "After updating, test SMS sending will work properly." 