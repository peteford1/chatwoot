#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'
require 'fileutils'

puts "🔄 Moving Conversation from Inbox 2 to Inbox 6..."

# Configuration
base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
account_id = 1
api_token = 'baea8676c67aba47c08564ce'
conversation_id = 1
source_inbox_id = 2
target_inbox_id = 6

puts "\n🎯 Migration Details:"
puts "   Conversation ID: #{conversation_id}"
puts "   From: Inbox #{source_inbox_id} (VoiceLinkAI - SMS, phone: 19795412927)"
puts "   To: Inbox #{target_inbox_id} (VoiceLink SMS, phone: +19795412927)"
puts "   Reason: Preparing to delete duplicate inbox #{source_inbox_id}"

# Helper function to make API requests
def make_api_request(method, url, headers, body = nil)
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  
  case method.upcase
  when 'GET'
    request = Net::HTTP::Get.new(uri)
  when 'POST'
    request = Net::HTTP::Post.new(uri)
  when 'PATCH'
    request = Net::HTTP::Patch.new(uri)
  when 'PUT'
    request = Net::HTTP::Put.new(uri)
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

# Step 1: Get conversation details before moving
puts "\n📋 Getting conversation details..."

conv_url = "#{base_url}/api/v1/accounts/#{account_id}/conversations/#{conversation_id}"
conv_response = make_api_request('GET', conv_url, headers)

if conv_response.code.to_i == 200
  begin
    conv_data = JSON.parse(conv_response.body)
    puts "   ✅ Found conversation:"
    puts "      ID: #{conv_data['id']}"
    puts "      Status: #{conv_data['status']}"
    puts "      Inbox ID: #{conv_data['inbox_id']}"
    puts "      Messages: #{conv_data['messages'] ? conv_data['messages'].length : 'N/A'}"
    
    if conv_data['meta'] && conv_data['meta']['sender']
      sender = conv_data['meta']['sender']
      puts "      Contact: #{sender['name']} (#{sender['phone_number']})"
    end
    
    # Create backup
    backup_info = {
      migration_timestamp: Time.now.strftime("%Y-%m-%dT%H:%M:%S%z"),
      conversation_id: conversation_id,
      source_inbox_id: source_inbox_id,
      target_inbox_id: target_inbox_id,
      original_conversation_data: conv_data,
      reason: "Moving conversation before deleting duplicate inbox"
    }
    
    backup_file = "backup/conversation_migration_#{conversation_id}_#{Time.now.to_i}.json"
    FileUtils.mkdir_p("backup")
    File.write(backup_file, JSON.pretty_generate(backup_info))
    puts "   💾 Backup saved: #{backup_file}"
    
  rescue JSON::ParserError => e
    puts "   ❌ Could not parse conversation details: #{e.message}"
    exit 1
  end
else
  puts "   ❌ Failed to get conversation details: #{conv_response.code}"
  puts "      Response: #{conv_response.body}" if conv_response.body
  exit 1
end

# Step 2: Move conversation to target inbox
puts "\n🚀 Moving conversation to inbox #{target_inbox_id}..."

# Try different API endpoints for moving conversations
move_endpoints = [
  # Method 1: Update conversation inbox_id directly
  {
    method: 'PATCH',
    url: "#{base_url}/api/v1/accounts/#{account_id}/conversations/#{conversation_id}",
    body: { inbox_id: target_inbox_id }
  },
  # Method 2: Transfer conversation
  {
    method: 'POST',
    url: "#{base_url}/api/v1/accounts/#{account_id}/conversations/#{conversation_id}/transfer",
    body: { inbox_id: target_inbox_id }
  },
  # Method 3: Assign to inbox
  {
    method: 'POST',
    url: "#{base_url}/api/v1/accounts/#{account_id}/conversations/#{conversation_id}/assignments",
    body: { inbox_id: target_inbox_id }
  }
]

success = false

move_endpoints.each_with_index do |endpoint, index|
  puts "\n   Attempt #{index + 1}: #{endpoint[:method]} #{endpoint[:url].split('/').last(2).join('/')}"
  
  response = make_api_request(endpoint[:method], endpoint[:url], headers, endpoint[:body])
  
  case response.code.to_i
  when 200..299
    puts "   ✅ SUCCESS: Conversation moved successfully"
    puts "      Status: #{response.code} #{response.message}"
    
    # Update backup with success
    backup_info[:migration_status] = "success"
    backup_info[:migration_method] = "#{endpoint[:method]} #{endpoint[:url]}"
    backup_info[:migration_response_code] = response.code.to_i
    backup_info[:migration_response_body] = response.body
    File.write(backup_file, JSON.pretty_generate(backup_info))
    
    success = true
    break
    
  when 400..499
    puts "   ❌ Client Error: #{response.code} #{response.message}"
    if response.body
      begin
        error_data = JSON.parse(response.body)
        puts "      Error: #{error_data['message'] || error_data['error']}"
      rescue JSON::ParserError
        puts "      Response: #{response.body[0..100]}"
      end
    end
    
  when 500..599
    puts "   💥 Server Error: #{response.code} #{response.message}"
    puts "      Response: #{response.body[0..100]}" if response.body
    
  else
    puts "   ⚠️  Unexpected Response: #{response.code} #{response.message}"
  end
end

if !success
  puts "\n❌ All migration attempts failed!"
  backup_info[:migration_status] = "failed"
  backup_info[:migration_error] = "All API endpoints failed"
  File.write(backup_file, JSON.pretty_generate(backup_info))
  exit 1
end

# Step 3: Verify the move
puts "\n🔍 Verifying conversation move..."

verify_response = make_api_request('GET', conv_url, headers)

if verify_response.code.to_i == 200
  begin
    verify_data = JSON.parse(verify_response.body)
    current_inbox_id = verify_data['inbox_id']
    
    if current_inbox_id == target_inbox_id
      puts "   ✅ Confirmed: Conversation now in inbox #{target_inbox_id}"
      backup_info[:verification_status] = "success"
    else
      puts "   ⚠️  Warning: Conversation still in inbox #{current_inbox_id}"
      backup_info[:verification_status] = "failed"
    end
    
  rescue JSON::ParserError
    puts "   ⚠️  Could not verify conversation location"
    backup_info[:verification_status] = "unknown"
  end
else
  puts "   ❌ Could not verify conversation: #{verify_response.code}"
  backup_info[:verification_status] = "error"
end

# Step 4: Check if inbox 2 is now empty
puts "\n📊 Checking if source inbox is now empty..."

conversations_url = "#{base_url}/api/v1/accounts/#{account_id}/conversations?inbox_id=#{source_inbox_id}"
check_response = make_api_request('GET', conversations_url, headers)

if check_response.code.to_i == 200
  begin
    check_data = JSON.parse(check_response.body)
    remaining_conversations = check_data['data']['payload'] || []
    
    puts "   📱 Remaining conversations in inbox #{source_inbox_id}: #{remaining_conversations.length}"
    
    if remaining_conversations.length == 0
      puts "   ✅ SUCCESS: Source inbox is now empty!"
      puts "   🎯 Ready to delete inbox #{source_inbox_id}"
      backup_info[:source_inbox_empty] = true
    else
      puts "   ⚠️  Warning: #{remaining_conversations.length} conversations still remain"
      backup_info[:source_inbox_empty] = false
    end
    
  rescue JSON::ParserError
    puts "   ⚠️  Could not check remaining conversations"
    backup_info[:source_inbox_empty] = "unknown"
  end
end

# Update final backup
File.write(backup_file, JSON.pretty_generate(backup_info))

puts "\n✨ Conversation migration completed!"
puts "   📄 Complete backup: #{backup_file}"

if success && backup_info[:verification_status] == "success" && backup_info[:source_inbox_empty]
  puts "   🎉 SUCCESS: Ready to delete duplicate inbox!"
else
  puts "   ⚠️  Check backup file for detailed results"
end 