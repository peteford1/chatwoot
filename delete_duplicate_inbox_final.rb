#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'
require 'fileutils'

puts "🗑️  Deleting Duplicate Inbox After Closing Conversations..."

# Configuration
base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
account_id = 1
api_token = 'baea8676c67aba47c08564ce'

# Target inbox to delete (the duplicate one)
target_inbox_id = 2  # VoiceLinkAI - SMS (+19795412927) with phone 19795412927

puts "\n🎯 Target for Deletion:"
puts "   Inbox ID: #{target_inbox_id}"
puts "   Name: VoiceLinkAI - SMS (+19795412927)"
puts "   Phone: 19795412927 (without + prefix)"
puts "   Reason: Duplicate of Inbox 6"

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
  when 'DELETE'
    request = Net::HTTP::Delete.new(uri)
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

# Step 1: Check current inbox status
puts "\n🔍 STEP 1: Checking Current Inbox Status..."

inboxes_url = "#{base_url}/api/v1/accounts/#{account_id}/inboxes"
inboxes_response = make_api_request('GET', inboxes_url, headers)

current_inboxes = []

if inboxes_response.code.to_i == 200
  begin
    inboxes_data = JSON.parse(inboxes_response.body)
    
    if inboxes_data.is_a?(Hash) && inboxes_data['payload']
      current_inboxes = inboxes_data['payload']
    elsif inboxes_data.is_a?(Array)
      current_inboxes = inboxes_data
    end
    
    puts "   ✅ Found #{current_inboxes.length} inboxes"
    
    # Show current inboxes
    current_inboxes.each do |inbox|
      phone = inbox.dig('channel', 'phone_number') || 'N/A'
      puts "      📥 ID #{inbox['id']}: #{inbox['name']} (#{phone})"
    end
    
    # Check if target inbox still exists
    target_inbox = current_inboxes.find { |inbox| inbox['id'] == target_inbox_id }
    
    if target_inbox
      puts "\n   🎯 Target inbox found:"
      puts "      ID: #{target_inbox['id']}"
      puts "      Name: #{target_inbox['name']}"
      puts "      Phone: #{target_inbox.dig('channel', 'phone_number')}"
      puts "      Channel Type: #{target_inbox.dig('channel', 'channel_type')}"
    else
      puts "\n   ✅ Target inbox (ID: #{target_inbox_id}) already deleted!"
      exit 0
    end
    
  rescue JSON::ParserError => e
    puts "   ❌ Could not parse inboxes response: #{e.message}"
    exit 1
  end
else
  puts "   ❌ Failed to get inboxes: #{inboxes_response.code}"
  exit 1
end

# Step 2: Check for active conversations in target inbox
puts "\n🔍 STEP 2: Checking for Active Conversations..."

conversations_url = "#{base_url}/api/v1/accounts/#{account_id}/conversations"
conversations_response = make_api_request('GET', conversations_url, headers)

active_conversations_in_target = []

if conversations_response.code.to_i == 200
  begin
    conversations_data = JSON.parse(conversations_response.body)
    
    if conversations_data.is_a?(Hash) && conversations_data['data'] && conversations_data['data']['payload']
      all_conversations = conversations_data['data']['payload']
    elsif conversations_data.is_a?(Array)
      all_conversations = conversations_data
    else
      all_conversations = []
    end
    
    puts "   ✅ Found #{all_conversations.length} total conversations"
    
    # Filter conversations for target inbox
    active_conversations_in_target = all_conversations.select do |conv|
      conv['inbox_id'] == target_inbox_id && conv['status'] != 'resolved'
    end
    
    puts "   📊 Conversations in target inbox (ID: #{target_inbox_id}):"
    
    target_conversations = all_conversations.select { |conv| conv['inbox_id'] == target_inbox_id }
    
    if target_conversations.any?
      target_conversations.each do |conv|
        status_icon = conv['status'] == 'resolved' ? '✅' : '⚠️'
        puts "      #{status_icon} ID #{conv['id']}: #{conv['status']} (#{conv['messages_count']} messages)"
      end
    else
      puts "      ✅ No conversations found in target inbox"
    end
    
    if active_conversations_in_target.any?
      puts "\n   ⚠️  Found #{active_conversations_in_target.length} active conversations - cannot delete inbox yet"
      
      # Try to resolve remaining conversations
      puts "\n🔧 Attempting to resolve active conversations..."
      
      active_conversations_in_target.each do |conv|
        puts "   📝 Resolving conversation ID: #{conv['id']}"
        
        resolve_url = "#{base_url}/api/v1/accounts/#{account_id}/conversations/#{conv['id']}"
        resolve_body = { status: 'resolved' }
        
        resolve_response = make_api_request('PATCH', resolve_url, headers, resolve_body)
        
        if resolve_response.code.to_i == 200
          puts "      ✅ Conversation resolved"
        else
          puts "      ❌ Failed to resolve: #{resolve_response.code}"
        end
      end
      
      # Wait a moment for processing
      puts "\n   ⏳ Waiting 3 seconds for conversation resolution..."
      sleep(3)
      
    else
      puts "\n   ✅ No active conversations blocking deletion"
    end
    
  rescue JSON::ParserError => e
    puts "   ❌ Could not parse conversations response: #{e.message}"
  end
else
  puts "   ❌ Failed to get conversations: #{conversations_response.code}"
end

# Step 3: Create backup before deletion
puts "\n💾 STEP 3: Creating Backup..."

backup_info = {
  deletion_timestamp: Time.now.strftime("%Y-%m-%dT%H:%M:%S%z"),
  target_inbox: target_inbox,
  reason: "Duplicate inbox cleanup",
  conversations_in_inbox: target_conversations || [],
  all_inboxes_before_deletion: current_inboxes
}

backup_file = "backup/inbox_deletion_#{target_inbox_id}_#{Time.now.to_i}.json"
FileUtils.mkdir_p("backup")
File.write(backup_file, JSON.pretty_generate(backup_info))

puts "   ✅ Backup created: #{backup_file}"

# Step 4: Attempt inbox deletion
puts "\n🗑️  STEP 4: Attempting Inbox Deletion..."

delete_url = "#{base_url}/api/v1/accounts/#{account_id}/inboxes/#{target_inbox_id}"
delete_response = make_api_request('DELETE', delete_url, headers)

puts "   Delete Response: #{delete_response.code}"

case delete_response.code.to_i
when 200..299
  puts "   🎉 DELETION SUCCESS!"
  
  begin
    delete_data = JSON.parse(delete_response.body)
    puts "   Response: #{delete_data}"
  rescue JSON::ParserError
    puts "   Deletion request accepted"
  end
  
when 404
  puts "   ✅ Inbox already deleted (404 Not Found)"
  
when 422
  puts "   ❌ Deletion failed: Validation error (422)"
  
  begin
    error_data = JSON.parse(delete_response.body)
    puts "   Error details: #{error_data}"
  rescue JSON::ParserError
    puts "   Raw error: #{delete_response.body}"
  end
  
else
  puts "   ❌ Deletion failed: #{delete_response.code}"
  puts "   Response: #{delete_response.body[0..200]}..."
end

# Step 5: Verify deletion
puts "\n🔍 STEP 5: Verifying Deletion..."

sleep(2)  # Wait for processing

final_inboxes_response = make_api_request('GET', inboxes_url, headers)

if final_inboxes_response.code.to_i == 200
  begin
    final_inboxes_data = JSON.parse(final_inboxes_response.body)
    
    if final_inboxes_data.is_a?(Hash) && final_inboxes_data['payload']
      final_inboxes = final_inboxes_data['payload']
    elsif final_inboxes_data.is_a?(Array)
      final_inboxes = final_inboxes_data
    end
    
    puts "   📊 Final inbox count: #{final_inboxes.length}"
    
    # Check if target inbox is gone
    remaining_target = final_inboxes.find { |inbox| inbox['id'] == target_inbox_id }
    
    if remaining_target
      puts "   ⚠️  Target inbox still exists - deletion may be processing"
    else
      puts "   ✅ Target inbox successfully deleted!"
    end
    
    puts "\n   📋 Remaining inboxes:"
    final_inboxes.each do |inbox|
      phone = inbox.dig('channel', 'phone_number') || 'N/A'
      puts "      📥 ID #{inbox['id']}: #{inbox['name']} (#{phone})"
    end
    
  rescue JSON::ParserError => e
    puts "   ❌ Could not parse final response: #{e.message}"
  end
else
  puts "   ❌ Failed to verify deletion: #{final_inboxes_response.code}"
end

# Step 6: Summary
puts "\n✨ DELETION PROCESS COMPLETED!"
puts "   📄 Backup: #{backup_file}"

if delete_response.code.to_i.between?(200, 299) || delete_response.code.to_i == 404
  puts "\n🎉 SUCCESS: Duplicate inbox deletion completed!"
  puts "   🗑️  Deleted: Inbox #{target_inbox_id} (VoiceLinkAI - SMS)"
  puts "   ✅ Remaining: Inbox 6 (VoiceLink SMS) with proper +19795412927 format"
  puts "   💡 Phone number conflict should now be resolved"
  
  puts "\n🔧 NEXT STEPS:"
  puts "   1. Try updating Twilio credentials on remaining inbox"
  puts "   2. Test SMS functionality"
  puts "   3. Verify webhook configuration"
  
else
  puts "\n⚠️  DELETION MAY HAVE FAILED"
  puts "   🔧 Manual intervention may be required"
  puts "   📋 Check backup file for details"
end

puts "\n📞 REMAINING TWILIO INBOX:"
remaining_twilio = final_inboxes&.find { |inbox| inbox.dig('channel', 'channel_type') == 'Channel::TwilioSms' }
if remaining_twilio
  puts "   📥 ID: #{remaining_twilio['id']}"
  puts "   📛 Name: #{remaining_twilio['name']}"
  puts "   📱 Phone: #{remaining_twilio.dig('channel', 'phone_number')}"
  puts "   🔗 Webhook: #{remaining_twilio.dig('channel', 'webhook_url')}"
end 