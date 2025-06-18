#!/usr/bin/env ruby

# Script to set up Twilio channel with proper error handling
# Run with: rails runner setup_twilio_channel.rb

def setup_twilio_channel
  puts "Setting up Twilio channel..."
  
  # Find or create the account
  account = Account.first
  if account.nil?
    puts "❌ No account found. Please create an account first."
    return
  end
  puts "✓ Using account: #{account.name} (ID: #{account.id})"

  begin
    # Create Twilio SMS Channel
    twilio_channel = account.twilio_sms.create!(
      account_sid: 'ACtest123456789',
      auth_token: 'test_auth_token_123456789',
      phone_number: '+19795412927',
      medium: 'sms'
    )
    puts "✓ Created Twilio channel with phone number: #{twilio_channel.phone_number}"

    # Create Inbox
    inbox = account.inboxes.create!(
      name: 'Twilio SMS Test',
      channel: twilio_channel
    )
    puts "✓ Created inbox: #{inbox.name} (ID: #{inbox.id})"

    puts "\nSetup completed successfully!"
    puts "\nChannel Details:"
    puts "- Account SID: #{twilio_channel.account_sid}"
    puts "- Phone Number: #{twilio_channel.phone_number}"
    puts "- Medium: #{twilio_channel.medium}"
    puts "- Inbox ID: #{inbox.id}"
    puts "\nWebhook URL should be configured in Twilio to:"
    puts "https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/twilio/callback"
    
  rescue ActiveRecord::RecordInvalid => e
    puts "\n❌ Failed to create channel/inbox:"
    puts e.record.errors.full_messages.join("\n")
  rescue StandardError => e
    puts "\n❌ An unexpected error occurred:"
    puts e.message
    puts e.backtrace.first(3)
  end
end

# Run the setup
setup_twilio_channel 