require 'net/http'
require 'json'
require 'uri'

# Test getting user token from Azure database
puts "Testing user token retrieval..."

# First, let's test if we can get user info from the database
uri = URI('https://voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/platform/accounts/1/users')
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

# Use platform token
platform_token = "Ej5HvBqhyc2dCzGxKpWn6Aqt"

puts "Getting users with platform token..."
request = Net::HTTP::Get.new(uri)
request['Authorization'] = "Bearer #{platform_token}"
request['Content-Type'] = 'application/json'

begin
  response = http.request(request)
  puts "Status: #{response.code}"
  puts "Response:"
  puts response.body
  
  if response.code == '200'
    users = JSON.parse(response.body)
    puts "\nFound #{users.length} users:"
    users.each do |user|
      puts "- ID: #{user['id']}, Email: #{user['email']}, Name: #{user['name']}"
    end
    
    # Try to get token for the first user
    if users.any?
      user_id = users.first['id']
      puts "\nTrying to get token for user ID: #{user_id}"
      
      # Test direct database query for token
      token_uri = URI('https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/platform/accounts/1/users/#{user_id}/token')
      token_request = Net::HTTP::Get.new(token_uri)
      token_request['Authorization'] = "Bearer #{platform_token}"
      token_request['Content-Type'] = 'application/json'
      
      token_response = http.request(token_request)
      puts "Token Status: #{token_response.code}"
      puts "Token Response: #{token_response.body}"
    end
  end
rescue => e
  puts "Error: #{e.message}"
end 