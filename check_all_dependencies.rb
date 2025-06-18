require 'net/http'
require 'json'
require 'uri'

base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
token = 'baea8676c67aba47c08564ce'

puts '🔍 Comprehensive dependency check for Inbox 2...'

http = Net::HTTP.new(URI(base_url).host, URI(base_url).port)
http.use_ssl = true

# Check 1: Inbox members/agents
puts "\n1️⃣ Checking inbox members/agents..."
uri = URI("#{base_url}/api/v1/accounts/1/inboxes/2/inbox_members")
request = Net::HTTP::Get.new(uri)
request['api_access_token'] = token

response = http.request(request)
if response.code == '200'
  data = JSON.parse(response.body)
  members = data['payload'] || []
  puts "   Found #{members.length} inbox members"
  
  members.each do |member|
    puts "     - Agent ID: #{member['user_id']}, Name: #{member['user']['name']}"
    
    # Try to remove the agent
    delete_uri = URI("#{base_url}/api/v1/accounts/1/inboxes/2/inbox_members")
    delete_request = Net::HTTP::Delete.new(delete_uri)
    delete_request['api_access_token'] = token
    delete_request['Content-Type'] = 'application/json'
    delete_request.body = { user_ids: [member['user_id']] }.to_json
    
    delete_response = http.request(delete_request)
    if delete_response.code == '200'
      puts "       ✅ Removed agent #{member['user_id']}"
    else
      puts "       ⚠️  Failed to remove agent: #{delete_response.code}"
    end
  end
else
  puts "   ❌ Error checking members: #{response.code} - #{response.body[0..200]}..."
end

# Check 2: Any remaining conversations
puts "\n2️⃣ Double-checking conversations..."
uri = URI("#{base_url}/api/v1/accounts/1/conversations")
uri.query = URI.encode_www_form({
  'inbox_id' => '2',
  'status' => 'all'
})

request = Net::HTTP::Get.new(uri)
request['api_access_token'] = token

response = http.request(request)
if response.code == '200'
  data = JSON.parse(response.body)
  conversations = data['data']['payload'] || []
  puts "   Found #{conversations.length} conversations"
  
  conversations.each do |conv|
    puts "     - Conversation ID: #{conv['id']}, Status: #{conv['status']}"
  end
else
  puts "   ❌ Error: #{response.code}"
end

# Check 3: Any remaining contacts
puts "\n3️⃣ Double-checking contacts..."
uri = URI("#{base_url}/api/v1/accounts/1/contacts")
uri.query = URI.encode_www_form({
  'inbox_id' => '2'
})

request = Net::HTTP::Get.new(uri)
request['api_access_token'] = token

response = http.request(request)
if response.code == '200'
  data = JSON.parse(response.body)
  contacts = data['payload'] || []
  puts "   Found #{contacts.length} contacts"
  
  contacts.each do |contact|
    puts "     - Contact ID: #{contact['id']}, Name: #{contact['name']}"
  end
else
  puts "   ❌ Error: #{response.code}"
end

# Check 4: Channel details
puts "\n4️⃣ Checking channel details..."
uri = URI("#{base_url}/api/v1/accounts/1/inboxes/2")
request = Net::HTTP::Get.new(uri)
request['api_access_token'] = token

response = http.request(request)
if response.code == '200'
  data = JSON.parse(response.body)
  inbox = data['payload']
  if inbox
    puts "   Channel Type: #{inbox['channel_type']}"
    puts "   Channel ID: #{inbox['channel_id']}"
    puts "   Phone Number: #{inbox['phone_number']}"
    puts "   Status: #{inbox['status'] || 'active'}"
    
    # Try to get channel details
    if inbox['channel_id']
      puts "\n   🔍 Checking channel #{inbox['channel_id']}..."
      channel_uri = URI("#{base_url}/api/v1/accounts/1/channels/twilio_sms/#{inbox['channel_id']}")
      channel_request = Net::HTTP::Get.new(channel_uri)
      channel_request['api_access_token'] = token
      
      channel_response = http.request(channel_request)
      if channel_response.code == '200'
        channel_data = JSON.parse(channel_response.body)
        puts "     Channel exists and is active"
      else
        puts "     Channel may not exist: #{channel_response.code}"
      end
    end
  else
    puts "   ⚠️  Inbox payload is nil"
  end
else
  puts "   ❌ Error: #{response.code}"
end

# Final attempt at deletion
puts "\n5️⃣ Final deletion attempt..."
uri = URI("#{base_url}/api/v1/accounts/1/inboxes/2")
request = Net::HTTP::Delete.new(uri)
request['api_access_token'] = token

response = http.request(request)
puts "   Response: #{response.code}"
if response.code == '200'
  puts "   ✅ Deletion request submitted again"
  
  # Wait and check
  puts "   Waiting 15 seconds..."
  sleep(15)
  
  # Final check
  uri = URI("#{base_url}/api/v1/accounts/1/inboxes")
  request = Net::HTTP::Get.new(uri)
  request['api_access_token'] = token
  
  response = http.request(request)
  if response.code == '200'
    data = JSON.parse(response.body)
    inboxes = data['payload'] || []
    
    if inboxes.any? { |inbox| inbox['id'] == 2 }
      puts "   ⚠️  Inbox 2 still exists - may require manual intervention"
    else
      puts "   🎉 SUCCESS! Inbox 2 has been deleted!"
    end
  end
else
  puts "   ❌ Error: #{response.body[0..300]}..."
end 