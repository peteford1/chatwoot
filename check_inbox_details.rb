require 'net/http'
require 'json'
require 'uri'

base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
token = 'baea8676c67aba47c08564ce'

puts '🔍 Checking detailed inbox configurations...'

http = Net::HTTP.new(URI(base_url).host, URI(base_url).port)
http.use_ssl = true

# Get all inboxes
uri = URI("#{base_url}/api/v1/accounts/1/inboxes")
request = Net::HTTP::Get.new(uri)
request['api_access_token'] = token

response = http.request(request)
if response.code == '200'
  data = JSON.parse(response.body)
  inboxes = data['payload'] || []
  
  puts "📋 Found #{inboxes.length} inboxes:"
  
  inboxes.each do |inbox|
    puts "\n" + "="*60
    puts "📥 INBOX #{inbox['id']}: #{inbox['name']}"
    puts "="*60
    
    # Get detailed info for each inbox
    detail_uri = URI("#{base_url}/api/v1/accounts/1/inboxes/#{inbox['id']}")
    detail_request = Net::HTTP::Get.new(detail_uri)
    detail_request['api_access_token'] = token
    
    detail_response = http.request(detail_request)
    if detail_response.code == '200'
      detail_data = JSON.parse(detail_response.body)
      inbox_detail = detail_data['payload']
      
      if inbox_detail
        puts "   📞 Phone Number: #{inbox_detail['phone_number'] || 'N/A'}"
        puts "   🏷️  Channel Type: #{inbox_detail['channel_type'] || 'N/A'}"
        puts "   🆔 Channel ID: #{inbox_detail['channel_id'] || 'N/A'}"
        puts "   📧 Email: #{inbox_detail['email'] || 'N/A'}"
        puts "   🌐 Website URL: #{inbox_detail['website_url'] || 'N/A'}"
        puts "   ⚙️  Status: #{inbox_detail['status'] || 'active'}"
        puts "   🕐 Created: #{inbox_detail['created_at']}"
        puts "   🕐 Updated: #{inbox_detail['updated_at']}"
        
        # Check if this is a Twilio SMS channel
        if inbox_detail['channel_type'] == 'Channel::TwilioSms'
          puts "   📱 Twilio SMS Configuration:"
          puts "     - Account SID: #{inbox_detail['account_sid'] || 'N/A'}"
          puts "     - Auth Token: #{inbox_detail['auth_token'] ? '[HIDDEN]' : 'N/A'}"
          puts "     - Medium: #{inbox_detail['medium'] || 'N/A'}"
        end
        
        # Check for any webhook URLs
        if inbox_detail['webhook_url']
          puts "   🔗 Webhook URL: #{inbox_detail['webhook_url']}"
        end
        
        # Check for any recent configuration changes
        created_time = Time.parse(inbox_detail['created_at']) rescue nil
        updated_time = Time.parse(inbox_detail['updated_at']) rescue nil
        
        if created_time && updated_time
          time_diff = updated_time - created_time
          if time_diff > 60 # More than 1 minute difference
            puts "   ⚠️  Configuration was updated #{((Time.now - updated_time) / 60).round} minutes ago"
          end
        end
        
      else
        puts "   ❌ Could not retrieve detailed configuration (payload is nil)"
        puts "   ⚠️  This inbox may be in a corrupted state"
      end
    else
      puts "   ❌ Error getting details: #{detail_response.code}"
      if detail_response.code == '404'
        puts "   ⚠️  Inbox may be in process of deletion"
      end
    end
  end
  
  # Summary of SMS inboxes
  puts "\n" + "="*60
  puts "📱 SMS INBOX SUMMARY"
  puts "="*60
  
  sms_inboxes = inboxes.select { |inbox| inbox['name']&.include?('+19795412927') }
  puts "Found #{sms_inboxes.length} inboxes with phone number +19795412927:"
  
  sms_inboxes.each do |inbox|
    status = inbox['id'] == 2 ? "🔴 DUPLICATE (STUCK)" : "🟢 ACTIVE"
    puts "   #{status} ID #{inbox['id']}: #{inbox['name']}"
  end
  
else
  puts "❌ Error getting inbox list: #{response.code} - #{response.body[0..200]}..."
end 