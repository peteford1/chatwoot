require 'net/http'
require 'json'
require 'uri'

base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
token = 'baea8676c67aba47c08564ce'

puts '🔍 Attempting to force delete Inbox 2...'

# First, let's check what's blocking the deletion
puts "\n1️⃣ Checking for contacts associated with Inbox 2..."
uri = URI("#{base_url}/api/v1/accounts/1/contacts")
uri.query = URI.encode_www_form({
  'inbox_id' => '2'
})

http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

request = Net::HTTP::Get.new(uri)
request['api_access_token'] = token

response = http.request(request)
if response.code == '200'
  data = JSON.parse(response.body)
  contacts = data['payload'] || []
  puts "   Found #{contacts.length} contacts associated with Inbox 2"
  
  if contacts.length > 0
    puts "   📋 Contacts:"
    contacts.each do |contact|
      puts "     - ID: #{contact['id']}, Name: #{contact['name']}, Phone: #{contact['phone_number']}"
    end
  end
else
  puts "   ❌ Error checking contacts: #{response.body[0..200]}..."
end

# Check for any messages in the inbox
puts "\n2️⃣ Checking for messages in Inbox 2..."
uri = URI("#{base_url}/api/v1/accounts/1/conversations/1/messages")
request = Net::HTTP::Get.new(uri)
request['api_access_token'] = token

response = http.request(request)
if response.code == '200'
  data = JSON.parse(response.body)
  messages = data['payload'] || []
  puts "   Found #{messages.length} messages in conversation 1"
else
  puts "   ❌ Error or conversation doesn't exist: #{response.code}"
end

# Try to delete the inbox again with a different approach
puts "\n3️⃣ Attempting direct inbox deletion..."
uri = URI("#{base_url}/api/v1/accounts/1/inboxes/2")
request = Net::HTTP::Delete.new(uri)
request['api_access_token'] = token
request['Content-Type'] = 'application/json'

response = http.request(request)
puts "   Delete response: #{response.code}"
if response.code != '200'
  puts "   Error: #{response.body[0..300]}..."
else
  puts "   ✅ Deletion request submitted successfully"
end

# Wait a moment and check status
puts "\n4️⃣ Waiting 5 seconds and checking status..."
sleep(5)

uri = URI("#{base_url}/api/v1/accounts/1/inboxes")
request = Net::HTTP::Get.new(uri)
request['api_access_token'] = token

response = http.request(request)
if response.code == '200'
  data = JSON.parse(response.body)
  inboxes = data['payload'] || []
  
  inbox_2_exists = inboxes.any? { |inbox| inbox['id'] == 2 }
  
  if inbox_2_exists
    puts "   ⚠️  Inbox 2 still exists"
  else
    puts "   ✅ Inbox 2 has been successfully deleted!"
  end
  
  puts "\n📋 Current inboxes:"
  inboxes.each do |inbox|
    puts "   - ID: #{inbox['id']}, Name: #{inbox['name']}"
  end
else
  puts "   ❌ Error checking final status: #{response.body[0..200]}..."
end 