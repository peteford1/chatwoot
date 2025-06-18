require 'net/http'
require 'json'
require 'uri'

base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
token = 'baea8676c67aba47c08564ce'

puts '🔥 FORCE DELETE INBOXES (Keep only ID 6)'
puts '=' * 50

http = Net::HTTP.new(URI(base_url).host, URI(base_url).port)
http.use_ssl = true

# Get current inboxes
uri = URI("#{base_url}/api/v1/accounts/1/inboxes")
request = Net::HTTP::Get.new(uri)
request['api_access_token'] = token

response = http.request(request)
if response.code == '200'
  data = JSON.parse(response.body)
  inboxes = data.is_a?(Array) ? data : (data['data'] || data['payload'] || [])
  
  puts "📋 Current inboxes: #{inboxes.length}"
  inboxes.each do |inbox|
    puts "   ID #{inbox['id']}: #{inbox['name']} (#{inbox['phone_number']})"
  end
  
  # Delete each inbox except ID 6
  inboxes_to_delete = inboxes.reject { |inbox| inbox['id'] == 6 }
  puts "\n🗑️ Deleting #{inboxes_to_delete.length} inboxes..."
  
  inboxes_to_delete.each do |inbox|
    inbox_id = inbox['id']
    inbox_name = inbox['name']
    
    puts "\n🎯 Deleting Inbox ID #{inbox_id}: #{inbox_name}"
    
    # Try multiple deletion attempts
    3.times do |attempt|
      puts "   Attempt #{attempt + 1}/3..."
      
      delete_uri = URI("#{base_url}/api/v1/accounts/1/inboxes/#{inbox_id}")
      delete_request = Net::HTTP::Delete.new(delete_uri)
      delete_request['api_access_token'] = token
      
      delete_response = http.request(delete_request)
      puts "   Status: #{delete_response.code}"
      puts "   Response: #{delete_response.body}" if delete_response.body && !delete_response.body.empty?
      
      if delete_response.code == '200'
        puts "   ✅ Deletion request accepted"
        break
      else
        puts "   ❌ Deletion failed"
        sleep(2) # Wait before retry
      end
    end
    
    # Verify deletion
    puts "   🔍 Verifying deletion..."
    verify_uri = URI("#{base_url}/api/v1/accounts/1/inboxes/#{inbox_id}")
    verify_request = Net::HTTP::Get.new(verify_uri)
    verify_request['api_access_token'] = token
    
    verify_response = http.request(verify_request)
    if verify_response.code == '404'
      puts "   ✅ Inbox successfully deleted"
    else
      puts "   ⚠️  Inbox still exists (status: #{verify_response.code})"
    end
  end
  
  # Final check
  puts "\n🔍 Final verification..."
  sleep(5) # Wait for any async operations
  
  final_response = http.request(request)
  if final_response.code == '200'
    final_data = JSON.parse(final_response.body)
    final_inboxes = final_data.is_a?(Array) ? final_data : (final_data['data'] || final_data['payload'] || [])
    
    puts "📊 Remaining inboxes: #{final_inboxes.length}"
    final_inboxes.each do |inbox|
      puts "   ID #{inbox['id']}: #{inbox['name']} (#{inbox['phone_number']})"
    end
    
    if final_inboxes.length == 1 && final_inboxes.first['id'] == 6
      puts "\n🎉 SUCCESS! Only target inbox ID 6 remains!"
    else
      puts "\n⚠️  Still have #{final_inboxes.length} inboxes. May need database-level cleanup."
    end
  end
  
else
  puts "❌ Could not get inbox list: #{response.code}"
end 