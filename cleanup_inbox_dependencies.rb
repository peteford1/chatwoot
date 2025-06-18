require 'net/http'
require 'json'
require 'uri'

base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
token = 'baea8676c67aba47c08564ce'

puts '🧹 Cleaning up Inbox 2 dependencies...'

http = Net::HTTP.new(URI(base_url).host, URI(base_url).port)
http.use_ssl = true

# Step 1: Delete the contact
puts "\n1️⃣ Deleting contact (ID: 1)..."
uri = URI("#{base_url}/api/v1/accounts/1/contacts/1")
request = Net::HTTP::Delete.new(uri)
request['api_access_token'] = token

response = http.request(request)
if response.code == '200'
  puts "   ✅ Contact deleted successfully"
else
  puts "   ⚠️  Contact deletion response: #{response.code} - #{response.body[0..200]}..."
end

# Step 2: Delete conversation 1 (which contains the 11 messages)
puts "\n2️⃣ Deleting conversation 1 (with 11 messages)..."
uri = URI("#{base_url}/api/v1/accounts/1/conversations/1")
request = Net::HTTP::Delete.new(uri)
request['api_access_token'] = token

response = http.request(request)
if response.code == '200'
  puts "   ✅ Conversation deleted successfully"
else
  puts "   ⚠️  Conversation deletion response: #{response.code} - #{response.body[0..200]}..."
end

# Step 3: Wait a moment for cleanup to process
puts "\n3️⃣ Waiting 3 seconds for cleanup to process..."
sleep(3)

# Step 4: Try to delete the inbox again
puts "\n4️⃣ Attempting inbox deletion after cleanup..."
uri = URI("#{base_url}/api/v1/accounts/1/inboxes/2")
request = Net::HTTP::Delete.new(uri)
request['api_access_token'] = token

response = http.request(request)
puts "   Delete response: #{response.code}"
if response.code == '200'
  puts "   ✅ Inbox deletion request submitted"
else
  puts "   ❌ Error: #{response.body[0..300]}..."
end

# Step 5: Wait and verify deletion
puts "\n5️⃣ Waiting 10 seconds and verifying deletion..."
sleep(10)

uri = URI("#{base_url}/api/v1/accounts/1/inboxes")
request = Net::HTTP::Get.new(uri)
request['api_access_token'] = token

response = http.request(request)
if response.code == '200'
  data = JSON.parse(response.body)
  inboxes = data['payload'] || []
  
  inbox_2_exists = inboxes.any? { |inbox| inbox['id'] == 2 }
  
  if inbox_2_exists
    puts "   ⚠️  Inbox 2 still exists - may need more time"
    target_inbox = inboxes.find { |inbox| inbox['id'] == 2 }
    puts "   Current status: #{target_inbox['name']}"
  else
    puts "   🎉 SUCCESS! Inbox 2 has been deleted!"
  end
  
  puts "\n📋 Remaining inboxes:"
  inboxes.each do |inbox|
    marker = inbox['id'] == 6 ? "🎯" : "📥"
    puts "   #{marker} ID: #{inbox['id']}, Name: #{inbox['name']}"
  end
  
  # Check for phone number conflicts
  sms_inboxes = inboxes.select { |inbox| inbox['name']&.include?('+19795412927') }
  if sms_inboxes.length == 1
    puts "\n✅ Phone number conflict resolved! Only one inbox with +19795412927 remains."
  elsif sms_inboxes.length > 1
    puts "\n⚠️  Still #{sms_inboxes.length} inboxes with +19795412927"
  end
else
  puts "   ❌ Error checking final status: #{response.body[0..200]}..."
end 