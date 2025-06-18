#!/usr/bin/env ruby

# Debug the actual service instance params access
# Run with: bundle exec rails runner debug_service_instance.rb

puts "Debugging actual service instance..."

# Webhook parameters
webhook_params = {
  'From' => '+14353397687',
  'To' => '+19795412927', 
  'Body' => 'Debug test message.',
  'AccountSid' => 'ACtest123456789',
  'SmsSid' => 'SM123456789',
  'MessageSid' => 'SM987654321',
  'MessagingServiceSid' => nil
}

puts "Original webhook_params:"
webhook_params.each { |k, v| puts "  #{k}: #{v.inspect}" }
puts ""

# Create the service
service = Twilio::IncomingMessageService.new(params: webhook_params)

# Access the params through the service
puts "Service params access:"
puts "  service.params: #{service.params.inspect}"
puts "  service.params.class: #{service.params.class}"
puts ""

# Test individual param access
puts "Individual param access:"
puts "  params['MessagingServiceSid']: #{service.params['MessagingServiceSid'].inspect}"
puts "  params['AccountSid']: #{service.params['AccountSid'].inspect}"
puts "  params['To']: #{service.params['To'].inspect}"
puts ""

# Test presence checks
puts "Presence checks:"
puts "  MessagingServiceSid.present?: #{service.params['MessagingServiceSid'].present?}"
puts "  AccountSid.present?: #{service.params['AccountSid'].present?}"
puts "  To.present?: #{service.params['To'].present?}"
puts ""

# Now let's step through the actual service method with debugging
puts "Stepping through service twilio_channel method..."

# Access the method in a way that lets us see what happens
class Twilio::IncomingMessageService
  def debug_twilio_channel
    puts "  Inside twilio_channel method"
    
    # First branch
    puts "  Checking MessagingServiceSid: #{params[:MessagingServiceSid].inspect}"
    if params[:MessagingServiceSid].present?
      puts "  MessagingServiceSid present, looking up..."
      @twilio_channel = ::Channel::TwilioSms.find_by(messaging_service_sid: params[:MessagingServiceSid])
      puts "  Found: #{@twilio_channel.inspect}"
    else
      puts "  MessagingServiceSid not present"
    end
    
    # Second branch
    puts "  Checking AccountSid and To..."
    puts "  AccountSid: #{params[:AccountSid].inspect}"
    puts "  To: #{params[:To].inspect}"
    puts "  AccountSid present?: #{params[:AccountSid].present?}"
    puts "  To present?: #{params[:To].present?}"
    
    if params[:AccountSid].present? && params[:To].present?
      puts "  Both present, executing find_by!"
      begin
        @twilio_channel ||= ::Channel::TwilioSms.find_by!(account_sid: params[:AccountSid], phone_number: params[:To])
        puts "  Result: #{@twilio_channel.inspect}"
      rescue => e
        puts "  Error: #{e.class} - #{e.message}"
      end
    else
      puts "  Conditions not met"
    end
    
    puts "  Final result: #{@twilio_channel.inspect}"
    @twilio_channel
  end
end

result = service.debug_twilio_channel
puts ""
puts "Debug method result: #{result.inspect}" 