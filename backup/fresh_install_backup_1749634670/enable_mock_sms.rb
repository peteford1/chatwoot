#!/usr/bin/env ruby

# Enable mock SMS sending for testing without real Twilio credentials
# Run with: bundle exec rails runner enable_mock_sms.rb

puts "🔧 Enabling mock SMS sending for testing..."

# Create a mock Twilio client class
class MockTwilioClient
  def messages
    MockMessagesResource.new
  end
end

class MockMessagesResource
  def create(**params)
    puts "📱 MOCK SMS SENT:"
    puts "  To: #{params[:to]}"
    puts "  From: #{params[:from] || params[:messaging_service_sid]}"
    puts "  Body: #{params[:body]}"
    puts "  Media: #{params[:media_url]}" if params[:media_url].present?
    
    # Return a mock message object
    OpenStruct.new(
      sid: "SM#{SecureRandom.hex(16)}",
      status: 'sent'
    )
  end
end

# Monkey patch the Twilio client to use mock
Channel::TwilioSms.class_eval do
  private
  
  def client
    MockTwilioClient.new
  end
end

puts "✅ Mock SMS sending enabled!"
puts ""
puts "Now all SMS replies will be logged to console instead of sent via Twilio."
puts "To test:"
puts "1. Send a test message from your UI"
puts "2. Check the Rails logs to see the mock SMS output"
puts ""
puts "To disable mock mode, restart your Rails server." 