#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

puts "🚀 Testing Direct API Access..."

# Test both gateway and direct backend
urls = [
  {
    name: "KrakenD Gateway",
    base: 'https://voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
  },
  {
    name: "Direct Backend",
    base: 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
  }
]

platform_token = 'YkT9vdgc2UFZ2kgMhPdEaajT'
account_id = 3

# Function to make API call
def make_api_call(url, token, token_header = 'api_access_token')
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = (uri.scheme == 'https')
  http.read_timeout = 10
  
  request = Net::HTTP::Get.new(uri)
  request[token_header] = token
  request['Content-Type'] = 'application/json'
  
  puts "📡 #{url}"
  
  begin
    response = http.request(request)
    puts "📊 #{response.code} - #{response.message}"
    
    if response.code == '200'
      data = JSON.parse(response.body)
      return data
    else
      puts "❌ #{response.body[0..100]}..."
      return nil
    end
  rescue => e
    puts "❌ Exception: #{e.message}"
    return nil
  end
end

urls.each do |url_config|
  puts "\n" + "="*60
  puts "🔍 Testing: #{url_config[:name]}"
  puts "="*60
  
  base_url = url_config[:base]
  
  # Test different endpoints
  endpoints = [
    "/platform/api/v1/accounts",
    "/platform/api/v1/accounts/#{account_id}",
    "/platform/api/v1/accounts/#{account_id}/account_users",
    "/api/v1/accounts/#{account_id}/agents",
    "/api/v1/accounts"
  ]
  
  endpoints.each do |endpoint|
    puts "\n🔗 #{endpoint}"
    data = make_api_call("#{base_url}#{endpoint}", platform_token)
    
    if data
      puts "✅ Success! Got data:"
      if data.is_a?(Array)
        puts "   Array with #{data.length} items"
        data.first(2).each_with_index do |item, index|
          puts "   #{index + 1}. #{item.keys.join(', ')}" if item.is_a?(Hash)
        end
      else
        puts "   #{data.keys.join(', ')}" if data.is_a?(Hash)
      end
    end
  end
end

puts "\n✨ API testing completed!" 