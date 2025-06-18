require 'net/http'
require 'json'
require 'uri'

base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
token = 'baea8676c67aba47c08564ce'

puts '🧹 COMPREHENSIVE CHATWOOT CLEANUP'
puts '=' * 50
puts 'Target: Keep only Inbox ID 6 (VoiceLink SMS +19795412927)'
puts 'Process: Messages → Conversations → Contacts → Inboxes'
puts '=' * 50

http = Net::HTTP.new(URI(base_url).host, URI(base_url).port)
http.use_ssl = true

# Helper method to make API calls
def make_request(http, method, uri, token, body = nil)
  case method.upcase
  when 'GET'
    request = Net::HTTP::Get.new(uri)
  when 'DELETE'
    request = Net::HTTP::Delete.new(uri)
  when 'POST'
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = body.to_json if body
  end
  
  request['api_access_token'] = token
  response = http.request(request)
  
  begin
    data = JSON.parse(response.body) if response.body && !response.body.empty?
  rescue JSON::ParserError
    data = nil
  end
  
  [response.code.to_i, data]
end

# Helper to extract data from response
def extract_data(response_data)
  return [] unless response_data
  
  if response_data.is_a?(Array)
    response_data
  elsif response_data.is_a?(Hash)
    # Handle nested structure like {"data": {"payload": [...]}}
    if response_data['data'] && response_data['data']['payload']
      response_data['data']['payload']
    else
      response_data['payload'] || response_data['data'] || response_data['conversations'] || response_data['contacts'] || response_data['inboxes'] || []
    end
  else
    []
  end
end

# Step 1: Get all conversations
puts "\n📋 STEP 1: Getting all conversations..."
status, conversations_response = make_request(http, 'GET', URI("#{base_url}/api/v1/accounts/1/conversations"), token)

if status == 200 && conversations_response
  conversations = extract_data(conversations_response)
  puts "   Found #{conversations.length} conversations"
  puts "   Response type: #{conversations_response.class}"
  
  if conversations.length > 0
    puts "   Sample conversation keys: #{conversations.first.keys}" if conversations.first.is_a?(Hash)
  end
  
  # Step 2: Delete all messages in each conversation
  puts "\n🗑️ STEP 2: Deleting all messages..."
  total_messages_deleted = 0
  
  conversations.each_with_index do |conversation, index|
    conv_id = conversation['id']
    puts "   Processing conversation #{conv_id} (#{index + 1}/#{conversations.length})..."
    
    # Get messages for this conversation
    status, messages_response = make_request(http, 'GET', URI("#{base_url}/api/v1/accounts/1/conversations/#{conv_id}/messages"), token)
    
    if status == 200 && messages_response
      messages = extract_data(messages_response)
      puts "     Found #{messages.length} messages"
      
      messages.each do |message|
        msg_id = message['id']
        status, _ = make_request(http, 'DELETE', URI("#{base_url}/api/v1/accounts/1/conversations/#{conv_id}/messages/#{msg_id}"), token)
        if status == 200
          total_messages_deleted += 1
          print "."
        else
          print "x"
        end
      end
      puts " (#{messages.length} messages processed)"
    else
      puts "     ⚠️  Could not get messages for conversation #{conv_id} (status: #{status})"
    end
  end
  
  puts "   ✅ Total messages deleted: #{total_messages_deleted}"
  
  # Step 3: Delete all conversations
  puts "\n🗑️ STEP 3: Deleting all conversations..."
  conversations_deleted = 0
  
  conversations.each_with_index do |conversation, index|
    conv_id = conversation['id']
    puts "   Deleting conversation #{conv_id} (#{index + 1}/#{conversations.length})..."
    
    status, _ = make_request(http, 'DELETE', URI("#{base_url}/api/v1/accounts/1/conversations/#{conv_id}"), token)
    if status == 200
      conversations_deleted += 1
      puts "     ✅ Deleted"
    else
      puts "     ❌ Failed (status: #{status})"
    end
  end
  
  puts "   ✅ Total conversations deleted: #{conversations_deleted}"
  
else
  puts "   ❌ Could not get conversations list (status: #{status})"
end

# Step 4: Get all contacts and delete them
puts "\n🗑️ STEP 4: Deleting all contacts..."
status, contacts_response = make_request(http, 'GET', URI("#{base_url}/api/v1/accounts/1/contacts"), token)

if status == 200 && contacts_response
  contacts = extract_data(contacts_response)
  puts "   Found #{contacts.length} contacts"
  
  contacts_deleted = 0
  contacts.each_with_index do |contact, index|
    contact_id = contact['id']
    puts "   Deleting contact #{contact_id} (#{index + 1}/#{contacts.length})..."
    
    status, _ = make_request(http, 'DELETE', URI("#{base_url}/api/v1/accounts/1/contacts/#{contact_id}"), token)
    if status == 200
      contacts_deleted += 1
      puts "     ✅ Deleted"
    else
      puts "     ❌ Failed (status: #{status})"
    end
  end
  
  puts "   ✅ Total contacts deleted: #{contacts_deleted}"
else
  puts "   ❌ Could not get contacts list (status: #{status})"
end

# Step 5: Get all inboxes and delete all except ID 6
puts "\n🗑️ STEP 5: Deleting all inboxes except ID 6..."
status, inboxes_response = make_request(http, 'GET', URI("#{base_url}/api/v1/accounts/1/inboxes"), token)

if status == 200 && inboxes_response
  inboxes = extract_data(inboxes_response)
  puts "   Found #{inboxes.length} inboxes"
  
  target_inbox = inboxes.find { |inbox| inbox['id'] == 6 }
  if target_inbox
    puts "   ✅ Target inbox found: ID 6 - #{target_inbox['name']}"
  else
    puts "   ⚠️  Target inbox ID 6 not found!"
  end
  
  inboxes_to_delete = inboxes.reject { |inbox| inbox['id'] == 6 }
  puts "   📋 Inboxes to delete: #{inboxes_to_delete.length}"
  
  inboxes_deleted = 0
  inboxes_to_delete.each_with_index do |inbox, index|
    inbox_id = inbox['id']
    inbox_name = inbox['name']
    puts "   Deleting inbox #{inbox_id} - #{inbox_name} (#{index + 1}/#{inboxes_to_delete.length})..."
    
    status, _ = make_request(http, 'DELETE', URI("#{base_url}/api/v1/accounts/1/inboxes/#{inbox_id}"), token)
    if status == 200
      inboxes_deleted += 1
      puts "     ✅ Deleted"
    else
      puts "     ❌ Failed (status: #{status})"
    end
  end
  
  puts "   ✅ Total inboxes deleted: #{inboxes_deleted}"
else
  puts "   ❌ Could not get inboxes list (status: #{status})"
end

# Step 6: Final verification
puts "\n🔍 STEP 6: Final verification..."
status, final_inboxes_response = make_request(http, 'GET', URI("#{base_url}/api/v1/accounts/1/inboxes"), token)

if status == 200 && final_inboxes_response
  final_inboxes = extract_data(final_inboxes_response)
  puts "   📊 Remaining inboxes: #{final_inboxes.length}"
  
  final_inboxes.each do |inbox|
    puts "     ✅ ID #{inbox['id']}: #{inbox['name']} (#{inbox['phone_number']})"
  end
  
  if final_inboxes.length == 1 && final_inboxes.first['id'] == 6
    puts "\n🎉 SUCCESS! Only target inbox remains!"
  else
    puts "\n⚠️  Cleanup may need additional attention"
  end
else
  puts "   ❌ Could not verify final state (status: #{status})"
end

puts "\n" + "=" * 50
puts "🧹 CLEANUP COMPLETE"
puts "=" * 50 