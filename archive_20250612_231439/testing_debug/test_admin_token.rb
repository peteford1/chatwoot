#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

puts "🚀 Testing with Admin Access Token..."

base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
admin_token = '0212af10d6c85e3f692325e0'  # From create_website_inbox.rb
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
  
  puts "📡 #{endpoint_name(url)}"
  puts "🔑 Token: #{token[0..8]}..."
  
  begin
    response = http.request(request)
    puts "📊 #{response.code} - #{response.message}"
    
    if response.code == '200'
      data = JSON.parse(response.body)
      puts "✅ Success!"
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

def endpoint_name(url)
  url.split('/').last(3).join('/')
end

# Test with both tokens
tokens = [
  { name: "Admin Token", token: admin_token, header: 'api_access_token' },
  { name: "Platform Token", token: platform_token, header: 'api_access_token' }
]

endpoints = [
  "/platform/api/v1/accounts",
  "/platform/api/v1/accounts/#{account_id}",
  "/platform/api/v1/accounts/#{account_id}/account_users",
  "/api/v1/accounts/#{account_id}/agents"
]

tokens.each do |token_config|
  puts "\n" + "="*60
  puts "🔍 Testing with: #{token_config[:name]}"
  puts "="*60
  
  endpoints.each do |endpoint|
    puts "\n🔗 #{endpoint}"
    data = make_api_call("#{base_url}#{endpoint}", token_config[:token], token_config[:header])
    
    if data
      if data.is_a?(Array)
        puts "   📋 Array with #{data.length} items"
        if data.length > 0 && data.first.is_a?(Hash)
          puts "   🔑 Keys: #{data.first.keys.join(', ')}"
          # Show user/agent info if available
          data.each_with_index do |item, index|
            if item['name'] || item['email']
              puts "   #{index + 1}. #{item['name']} (#{item['email']}) - ID: #{item['id']}"
            end
          end
        end
      elsif data.is_a?(Hash)
        puts "   📋 Hash with keys: #{data.keys.join(', ')}"
        if data['name'] || data['email']
          puts "   👤 #{data['name']} (#{data['email']}) - ID: #{data['id']}"
        end
      end
    end
  end
end

puts "\n✨ Token testing completed!" 