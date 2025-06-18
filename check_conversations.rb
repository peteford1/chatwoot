#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

puts "📞 Checking Conversations in Inbox 2..."

# Configuration
base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
account_id = 1
api_token = 'baea8676c67aba47c08564ce'
inbox_id = 2

# Helper function to make API requests
def make_api_request(method, url, headers)
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  
  request = Net::HTTP::Get.new(uri)
  headers.each { |key, value| request[key] = value }
  
  http.request(request)
end

headers = {
  'api_access_token' => api_token,
  'Content-Type' => 'application/json',
  'Accept' => 'application/json'
}

# Get conversations for inbox 2
conversations_url = "#{base_url}/api/v1/accounts/#{account_id}/conversations?inbox_id=#{inbox_id}"
puts "🔗 URL: #{conversations_url}"

response = make_api_request('GET', conversations_url, headers)
puts "📊 Response Code: #{response.code}"

if response.code.to_i == 200
  puts "✅ Success! Raw response:"
  puts response.body[0..500] + "..."
  
  begin
    data = JSON.parse(response.body)
    puts "\n📋 Parsed data structure:"
    puts "   Type: #{data.class}"
    puts "   Keys: #{data.keys}" if data.is_a?(Hash)
    
    # Try to find conversations
    conversations = nil
    if data.is_a?(Hash)
      conversations = data['data'] || data['payload'] || data['conversations']
    elsif data.is_a?(Array)
      conversations = data
    end
    
    if conversations
      puts "   Conversations found: #{conversations.length}"
      
      conversations.each_with_index do |conv, index|
        puts "\n#{index + 1}. Conversation:"
        if conv.is_a?(Hash)
          conv.each do |key, value|
            puts "   #{key}: #{value.to_s[0..50]}"
          end
        else
          puts "   Raw: #{conv.inspect[0..100]}"
        end
      end
    else
      puts "   ❌ Could not find conversations in response"
    end
    
  rescue JSON::ParserError => e
    puts "❌ JSON Parse Error: #{e.message}"
  end
else
  puts "❌ Failed: #{response.code} #{response.message}"
  puts "Response: #{response.body}" if response.body
end

puts "\n✨ Done!" 