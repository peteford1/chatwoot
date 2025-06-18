#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'
require 'fileutils'

puts "🗑️  Deleting Conversation and Duplicate Inbox..."

# Configuration
base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
account_id = 1
api_token = 'baea8676c67aba47c08564ce'
conversation_id = 1
inbox_to_delete_id = 2

puts "\n⚠️  WARNING: This will permanently delete conversation data!"
puts "\n🎯 Deletion Plan:"
puts "   1. Delete Conversation ID: #{conversation_id}"
puts "      - Contact: Test User (+14353397687)"
puts "      - Messages: 1 message"
puts "      - Content: Test conversation"
puts "   2. Delete Inbox ID: #{inbox_to_delete_id}"
puts "      - Name: VoiceLinkAI - SMS (+19795412927)"
puts "      - Phone: 19795412927 (duplicate of inbox 6)"

# Helper function to make API requests
def make_api_request(method, url, headers, body = nil)
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  
  case method.upcase
  when 'GET'
    request = Net::HTTP::Get.new(uri)
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

# Create backup before deletion
puts "\n💾 Creating backup before deletion..."

backup_info = {
  deletion_timestamp: Time.now.strftime("%Y-%m-%dT%H:%M:%S%z"),
  account_id: account_id,
  conversation_id: conversation_id,
  inbox_id: inbox_to_delete_id,
  reason: "Deleting conversation and duplicate inbox to resolve phone number conflict",
  phone_number_conflict: "Inbox 2 (19795412927) vs Inbox 6 (+19795412927)"
}

backup_file = "backup/conversation_and_inbox_deletion_#{Time.now.to_i}.json"
FileUtils.mkdir_p("backup")

# Step 1: Get conversation details for backup
puts "\n📋 Getting conversation details for backup..."

conv_url = "#{base_url}/api/v1/accounts/#{account_id}/conversations/#{conversation_id}"
conv_response = make_api_request('GET', conv_url, headers)

if conv_response.code.to_i == 200
  begin
    conv_data = JSON.parse(conv_response.body)
    backup_info[:conversation_data] = conv_data
    puts "   ✅ Conversation data backed up"
  rescue JSON::ParserError => e
    puts "   ⚠️  Could not parse conversation data: #{e.message}"
  end
else
  puts "   ⚠️  Could not fetch conversation data: #{conv_response.code}"
end

# Step 2: Get inbox details for backup
puts "\n📋 Getting inbox details for backup..."

inbox_url = "#{base_url}/api/v1/accounts/#{account_id}/inboxes/#{inbox_to_delete_id}"
inbox_response = make_api_request('GET', inbox_url, headers)

if inbox_response.code.to_i == 200
  begin
    inbox_data = JSON.parse(inbox_response.body)
    backup_info[:inbox_data] = inbox_data
    puts "   ✅ Inbox data backed up"
  rescue JSON::ParserError => e
    puts "   ⚠️  Could not parse inbox data: #{e.message}"
  end
else
  puts "   ⚠️  Could not fetch inbox data: #{inbox_response.code}"
end

# Save initial backup
File.write(backup_file, JSON.pretty_generate(backup_info))
puts "   📄 Initial backup saved: #{backup_file}"

# Step 3: Delete the conversation
puts "\n🗑️  Deleting conversation #{conversation_id}..."

delete_conv_url = "#{base_url}/api/v1/accounts/#{account_id}/conversations/#{conversation_id}"
delete_conv_response = make_api_request('DELETE', delete_conv_url, headers)

case delete_conv_response.code.to_i
when 200..299
  puts "   ✅ SUCCESS: Conversation deleted"
  puts "      Status: #{delete_conv_response.code} #{delete_conv_response.message}"
  
  backup_info[:conversation_deletion] = {
    status: "success",
    response_code: delete_conv_response.code.to_i,
    response_body: delete_conv_response.body
  }
  
when 400..499
  puts "   ❌ CLIENT ERROR: #{delete_conv_response.code} #{delete_conv_response.message}"
  if delete_conv_response.body
    begin
      error_data = JSON.parse(delete_conv_response.body)
      puts "      Error: #{error_data['message'] || error_data['error']}"
    rescue JSON::ParserError
      puts "      Response: #{delete_conv_response.body[0..200]}"
    end
  end
  
  backup_info[:conversation_deletion] = {
    status: "failed",
    response_code: delete_conv_response.code.to_i,
    error: delete_conv_response.body
  }
  
when 500..599
  puts "   💥 SERVER ERROR: #{delete_conv_response.code} #{delete_conv_response.message}"
  puts "      Response: #{delete_conv_response.body[0..200]}" if delete_conv_response.body
  
  backup_info[:conversation_deletion] = {
    status: "server_error",
    response_code: delete_conv_response.code.to_i,
    error: delete_conv_response.body
  }
  
else
  puts "   ⚠️  UNEXPECTED RESPONSE: #{delete_conv_response.code} #{delete_conv_response.message}"
  
  backup_info[:conversation_deletion] = {
    status: "unexpected",
    response_code: delete_conv_response.code.to_i,
    error: delete_conv_response.body
  }
end

# Step 4: Verify conversation deletion
puts "\n🔍 Verifying conversation deletion..."

verify_conv_response = make_api_request('GET', delete_conv_url, headers)

if verify_conv_response.code.to_i == 404
  puts "   ✅ Confirmed: Conversation no longer exists"
  backup_info[:conversation_verification] = "deleted"
elsif verify_conv_response.code.to_i == 200
  puts "   ⚠️  Warning: Conversation still exists"
  backup_info[:conversation_verification] = "still_exists"
else
  puts "   ⚠️  Verification inconclusive: #{verify_conv_response.code}"
  backup_info[:conversation_verification] = "inconclusive"
end

# Step 5: Check if inbox is now empty
puts "\n📊 Checking if inbox is now empty..."

conversations_url = "#{base_url}/api/v1/accounts/#{account_id}/conversations?inbox_id=#{inbox_to_delete_id}"
check_response = make_api_request('GET', conversations_url, headers)

if check_response.code.to_i == 200
  begin
    check_data = JSON.parse(check_response.body)
    remaining_conversations = check_data['data']['payload'] || []
    
    puts "   📱 Remaining conversations in inbox #{inbox_to_delete_id}: #{remaining_conversations.length}"
    
    if remaining_conversations.length == 0
      puts "   ✅ SUCCESS: Inbox is now empty!"
      backup_info[:inbox_empty] = true
    else
      puts "   ⚠️  Warning: #{remaining_conversations.length} conversations still remain"
      backup_info[:inbox_empty] = false
    end
    
  rescue JSON::ParserError
    puts "   ⚠️  Could not check remaining conversations"
    backup_info[:inbox_empty] = "unknown"
  end
end

# Step 6: Delete the inbox (only if empty)
if backup_info[:inbox_empty] == true
  puts "\n🗑️  Deleting empty inbox #{inbox_to_delete_id}..."
  
  delete_inbox_url = "#{base_url}/api/v1/accounts/#{account_id}/inboxes/#{inbox_to_delete_id}"
  delete_inbox_response = make_api_request('DELETE', delete_inbox_url, headers)
  
  case delete_inbox_response.code.to_i
  when 200..299
    puts "   ✅ SUCCESS: Inbox deletion initiated"
    puts "      Status: #{delete_inbox_response.code} #{delete_inbox_response.message}"
    puts "      Response: #{delete_inbox_response.body}"
    
    backup_info[:inbox_deletion] = {
      status: "success",
      response_code: delete_inbox_response.code.to_i,
      response_body: delete_inbox_response.body
    }
    
  when 400..499
    puts "   ❌ CLIENT ERROR: #{delete_inbox_response.code} #{delete_inbox_response.message}"
    if delete_inbox_response.body
      puts "      Response: #{delete_inbox_response.body[0..200]}"
    end
    
    backup_info[:inbox_deletion] = {
      status: "failed",
      response_code: delete_inbox_response.code.to_i,
      error: delete_inbox_response.body
    }
    
  when 500..599
    puts "   💥 SERVER ERROR: #{delete_inbox_response.code} #{delete_inbox_response.message}"
    puts "      Response: #{delete_inbox_response.body[0..200]}" if delete_inbox_response.body
    
    backup_info[:inbox_deletion] = {
      status: "server_error",
      response_code: delete_inbox_response.code.to_i,
      error: delete_inbox_response.body
    }
    
  else
    puts "   ⚠️  UNEXPECTED RESPONSE: #{delete_inbox_response.code} #{delete_inbox_response.message}"
    
    backup_info[:inbox_deletion] = {
      status: "unexpected",
      response_code: delete_inbox_response.code.to_i,
      error: delete_inbox_response.body
    }
  end
  
else
  puts "\n⚠️  Skipping inbox deletion - inbox not confirmed empty"
  backup_info[:inbox_deletion] = {
    status: "skipped",
    reason: "inbox_not_empty"
  }
end

# Update final backup
File.write(backup_file, JSON.pretty_generate(backup_info))

puts "\n✨ Deletion process completed!"
puts "   📄 Complete backup: #{backup_file}"

# Final status summary
if backup_info[:conversation_deletion] && backup_info[:conversation_deletion][:status] == "success" &&
   backup_info[:inbox_deletion] && backup_info[:inbox_deletion][:status] == "success"
  puts "   🎉 SUCCESS: Conversation and duplicate inbox deleted!"
  puts "   🎯 Phone number conflict should now be resolved"
else
  puts "   ⚠️  Check backup file for detailed results"
  puts "   📋 Next steps may be needed to complete cleanup"
end 