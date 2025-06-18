#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

puts "🔍 Checking Inbox 2 Dependencies..."

# Configuration
base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
account_id = 1
api_token = 'baea8676c67aba47c08564ce'
inbox_id = 2

puts "\n🎯 Target Inbox:"
puts "   Inbox ID: #{inbox_id}"
puts "   Name: VoiceLinkAI - SMS (+19795412927)"

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

# Check 1: Get conversations for this inbox
puts "\n📞 Checking conversations in inbox #{inbox_id}..."

conversations_url = "#{base_url}/api/v1/accounts/#{account_id}/conversations?inbox_id=#{inbox_id}"
conv_response = make_api_request('GET', conversations_url, headers)

if conv_response.code.to_i == 200
  begin
    conv_data = JSON.parse(conv_response.body)
    conversations = conv_data['data'] || conv_data['payload'] || conv_data
    
    puts "   📊 Found #{conversations.length} conversations"
    
    if conversations.length > 0
      puts "   ⚠️  BLOCKING FACTOR: Inbox has active conversations!"
      
      conversations.first(3).each_with_index do |conv, index|
        puts "\n   #{index + 1}. Conversation ID: #{conv['id']}"
        puts "      Status: #{conv['status']}"
        puts "      Messages: #{conv['messages_count'] || 'N/A'}"
        puts "      Created: #{conv['created_at']}"
        puts "      Contact: #{conv['meta'] && conv['meta']['sender'] ? conv['meta']['sender']['name'] : 'N/A'}"
      end
      
      if conversations.length > 3
        puts "   ... and #{conversations.length - 3} more conversations"
      end
    else
      puts "   ✅ No conversations found"
    end
    
  rescue JSON::ParserError => e
    puts "   ❌ Could not parse conversations response: #{e.message}"
  end
else
  puts "   ❌ Failed to fetch conversations: #{conv_response.code}"
  puts "      Response: #{conv_response.body[0..200]}" if conv_response.body
end

# Check 2: Get inbox members/agents
puts "\n👥 Checking inbox members..."

members_url = "#{base_url}/api/v1/accounts/#{account_id}/inboxes/#{inbox_id}/inbox_members"
members_response = make_api_request('GET', members_url, headers)

if members_response.code.to_i == 200
  begin
    members_data = JSON.parse(members_response.body)
    members = members_data['payload'] || members_data
    
    puts "   👤 Found #{members.length} inbox members"
    
    if members.length > 0
      puts "   ⚠️  POTENTIAL BLOCKING FACTOR: Inbox has assigned agents"
      
      members.each do |member|
        puts "      - Agent ID: #{member['id']}, Name: #{member['name']}, Email: #{member['email']}"
      end
    else
      puts "   ✅ No inbox members found"
    end
    
  rescue JSON::ParserError => e
    puts "   ❌ Could not parse members response: #{e.message}"
  end
else
  puts "   ❌ Failed to fetch inbox members: #{members_response.code}"
  puts "      Response: #{members_response.body[0..200]}" if members_response.body
end

# Check 3: Get inbox details to see current status
puts "\n📋 Checking current inbox status..."

inbox_url = "#{base_url}/api/v1/accounts/#{account_id}/inboxes/#{inbox_id}"
inbox_response = make_api_request('GET', inbox_url, headers)

if inbox_response.code.to_i == 200
  begin
    inbox_data = JSON.parse(inbox_response.body)
    
    puts "   📊 Current inbox status:"
    puts "      ID: #{inbox_data['id']}"
    puts "      Name: #{inbox_data['name']}"
    puts "      Channel ID: #{inbox_data['channel_id']}"
    puts "      Phone: #{inbox_data['phone_number']}"
    puts "      Auto Assignment: #{inbox_data['enable_auto_assignment']}"
    puts "      CSAT Enabled: #{inbox_data['csat_survey_enabled']}"
    
    # Check if there are any special flags or statuses
    if inbox_data['status']
      puts "      Status: #{inbox_data['status']}"
    end
    
    if inbox_data['deleted_at']
      puts "      🗑️  Deleted At: #{inbox_data['deleted_at']}"
    end
    
  rescue JSON::ParserError => e
    puts "   ❌ Could not parse inbox response: #{e.message}"
  end
elsif inbox_response.code.to_i == 404
  puts "   ✅ Inbox not found - deletion may have completed!"
else
  puts "   ❌ Failed to fetch inbox: #{inbox_response.code}"
  puts "      Response: #{inbox_response.body[0..200]}" if inbox_response.body
end

# Check 4: Try to get channel details
puts "\n📡 Checking channel details..."

# Since we know it's channel_id 2 from the backup
channel_id = 2

# This might not work via API, but let's see what we can find
puts "   Channel ID: #{channel_id}"
puts "   Channel Type: Channel::Sms"
puts "   Phone Number: 19795412927"

# Summary and recommendations
puts "\n📝 SUMMARY & RECOMMENDATIONS:"

puts "\n🔍 Possible reasons for deletion delay/failure:"
puts "   1. Asynchronous processing - deletion queued but not yet processed"
puts "   2. Active conversations preventing deletion"
puts "   3. Assigned agents/members blocking deletion"
puts "   4. Channel dependencies (SMS provider configuration)"
puts "   5. Webhook dependencies or external integrations"

puts "\n💡 Next steps to try:"
puts "   1. Wait longer (up to 30 minutes) for async processing"
puts "   2. Remove all conversations from the inbox first"
puts "   3. Unassign all agents from the inbox"
puts "   4. Try deleting via direct database access (if safe)"
puts "   5. Contact system administrator for manual cleanup"

puts "\n⚠️  IMPORTANT: The duplicate still exists, so the phone number conflict remains!"

puts "\n✨ Dependency check completed!" 