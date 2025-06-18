#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

puts "🔍 Checking Inbox Deletion Status..."

# Configuration
base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
account_id = 1
api_token = 'baea8676c67aba47c08564ce'
target_inbox_id = 2

# Helper function to make API requests
def make_api_request(method, url, headers, body = nil)
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  
  case method.upcase
  when 'GET'
    request = Net::HTTP::Get.new(uri)
  end
  
  headers.each { |key, value| request[key] = value }
  request.body = body.to_json if body
  
  http.request(request)
end

headers = {
  'api_access_token' => api_token,
  'Content-Type' => 'application/json',
  'Accept' => 'application/json'
}

# Check current inboxes
inboxes_url = "#{base_url}/api/v1/accounts/#{account_id}/inboxes"
inboxes_response = make_api_request('GET', inboxes_url, headers)

if inboxes_response.code.to_i == 200
  begin
    inboxes_data = JSON.parse(inboxes_response.body)
    
    if inboxes_data.is_a?(Hash) && inboxes_data['payload']
      current_inboxes = inboxes_data['payload']
    elsif inboxes_data.is_a?(Array)
      current_inboxes = inboxes_data
    end
    
    puts "\n📊 Current Inbox Status:"
    puts "   Total inboxes: #{current_inboxes.length}"
    
    # Check if target inbox still exists
    target_inbox = current_inboxes.find { |inbox| inbox['id'] == target_inbox_id }
    
    if target_inbox
      puts "   ⚠️  Target inbox (ID: #{target_inbox_id}) still exists"
      puts "      Name: #{target_inbox['name']}"
      puts "      Status: Deletion still processing..."
    else
      puts "   ✅ Target inbox (ID: #{target_inbox_id}) successfully deleted!"
    end
    
    puts "\n📋 All Current Inboxes:"
    current_inboxes.each do |inbox|
      channel_info = inbox['channel'] || {}
      phone = channel_info['phone_number'] || 'N/A'
      channel_type = channel_info['channel_type'] || 'Unknown'
      
      status_icon = inbox['id'] == target_inbox_id ? '🎯' : '📥'
      puts "      #{status_icon} ID #{inbox['id']}: #{inbox['name']}"
      puts "         Type: #{channel_type}"
      puts "         Phone: #{phone}" if phone != 'N/A'
    end
    
    # Look for Twilio SMS inboxes specifically
    twilio_inboxes = current_inboxes.select { |inbox| 
      inbox.dig('channel', 'channel_type') == 'Channel::TwilioSms' 
    }
    
    puts "\n📞 Twilio SMS Inboxes:"
    if twilio_inboxes.any?
      twilio_inboxes.each do |inbox|
        puts "   📱 ID #{inbox['id']}: #{inbox['name']}"
        puts "      Phone: #{inbox.dig('channel', 'phone_number')}"
        puts "      Webhook: #{inbox.dig('channel', 'webhook_url')}"
      end
    else
      puts "   ❌ No Twilio SMS inboxes found"
    end
    
  rescue JSON::ParserError => e
    puts "   ❌ Could not parse response: #{e.message}"
  end
else
  puts "   ❌ Failed to get inboxes: #{inboxes_response.code}"
end 