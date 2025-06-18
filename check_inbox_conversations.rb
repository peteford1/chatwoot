require 'net/http'
require 'json'
require 'uri'

base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
token = 'baea8676c67aba47c08564ce'

puts '🔍 Checking conversations in Inbox 2...'

# Check conversations for inbox 2
uri = URI("#{base_url}/api/v1/accounts/1/conversations")
uri.query = URI.encode_www_form({
  'inbox_id' => '2',
  'status' => 'all'
})

http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

request = Net::HTTP::Get.new(uri)
request['api_access_token'] = token

response = http.request(request)
puts "📊 API Response Status: #{response.code}"

conversations_to_delete = []

if response.code == '200'
  data = JSON.parse(response.body)
  conversations = data['data']['payload'] || []
  puts "   Found #{conversations.length} conversations in Inbox 2"
  
  if conversations.length > 0
    puts '   📋 Conversations blocking deletion:'
    conversations.each do |conv|
      puts "     - ID: #{conv['id']}, Status: #{conv['status']}, Messages: #{conv['messages_count'] || 0}"
      conversations_to_delete << conv['id']
    end
    puts "\n⚠️  These conversations are preventing inbox deletion"
    
    # Delete the blocking conversations
    puts "\n🗑️  Deleting blocking conversations..."
    conversations_to_delete.each do |conv_id|
      delete_uri = URI("#{base_url}/api/v1/accounts/1/conversations/#{conv_id}")
      delete_request = Net::HTTP::Delete.new(delete_uri)
      delete_request['api_access_token'] = token
      
      delete_response = http.request(delete_request)
      if delete_response.code == '200'
        puts "   ✅ Deleted conversation #{conv_id}"
      else
        puts "   ❌ Failed to delete conversation #{conv_id}: #{delete_response.body}"
      end
    end
  else
    puts '   ✅ No conversations found - inbox should be safe to delete'
  end
else
  puts "   ❌ Error checking conversations: #{response.body}"
end

# Also check inbox details
puts "\n🔍 Checking Inbox 2 details..."
uri = URI("#{base_url}/api/v1/accounts/1/inboxes/2")
request = Net::HTTP::Get.new(uri)
request['api_access_token'] = token

response = http.request(request)
if response.code == '200'
  data = JSON.parse(response.body)
  inbox = data['payload']
  if inbox
    puts "   Name: #{inbox['name']}"
    puts "   Channel Type: #{inbox['channel_type']}"
    puts "   Phone Number: #{inbox['phone_number']}"
    puts "   Status: #{inbox['status'] || 'Active'}"
  else
    puts "   ⚠️  Inbox data is nil - may already be deleted"
  end
else
  puts "   ❌ Error getting inbox details: #{response.body}"
end 