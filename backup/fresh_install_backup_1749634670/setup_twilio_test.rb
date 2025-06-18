#!/usr/bin/env ruby

# Setup script for Twilio test channel
# Run with: bundle exec rails runner setup_twilio_test.rb

puts "Setting up Twilio test channel..."

# Find the test account (assuming it's the first one, or find by domain/name)
account = Account.first
puts "Using account: #{account.name} (ID: #{account.id})"

# Create Twilio SMS Channel
twilio_channel = Channel::TwilioSms.create!(
  account: account,
  account_sid: 'ACtest123456789', # Test Twilio Account SID
  auth_token: 'test_auth_token_123456789', # Test Auth Token
  phone_number: '+19795412927',
  medium: 'sms'
)

puts "Created Twilio channel with phone number: #{twilio_channel.phone_number}"

# Create Inbox for the channel
inbox = Inbox.create!(
  account: account,
  name: 'Twilio SMS Test',
  channel: twilio_channel
)

puts "Created inbox: #{inbox.name} (ID: #{inbox.id})"
puts "Twilio channel setup complete!"
puts ""
puts "Channel Details:"
puts "- Account SID: #{twilio_channel.account_sid}"
puts "- Phone Number: #{twilio_channel.phone_number}"
puts "- Medium: #{twilio_channel.medium}"
puts "- Inbox ID: #{inbox.id}"
puts ""
puts "Webhook URL should be configured in Twilio to:"
puts "https://chatwoot-security-gateway.eastus.azurecontainer.io:8080/twilio/callback" 