#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

puts "🔑 Testing Chatwoot API Tokens..."

# API tokens to test
tokens = {
  "CHATWOOT_ADMIN_API_TOKEN" => "YkT9vdgc2UFZ2kgMhPdEaajT",
  "CHATWOOT_API_TOKEN" => "zEGFZ3658VdbbvkCTrpy8C5z"
}

# API base URL
API_BASE = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'

# Test endpoints
endpoints = [
  '/api/v1/profile',
  '/api/v1/accounts',
  '/api/v1/accounts/1/agents',
  '/api/v1/accounts/2/agents',
  '/platform/api/v1/accounts/1',
  '/platform/api/v1/accounts/2',
  '/super_admin/users'
]

def test_api_call(url, token, token_name)
  puts "\n📡 Testing: #{url}"
  puts "🔑 Token: #{token_name}"
  
  begin
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 15
    
    request = Net::HTTP::Get.new(uri)
    request['api_access_token'] = token
    request['Content-Type'] = 'application/json'
    
    response = http.request(request)
    
    puts "📊 Response Code: #{response.code}"
    
    case response.code
    when '200'
      puts "✅ SUCCESS!"
      data = JSON.parse(response.body) rescue response.body
      if data.is_a?(Array)
        puts "📄 Response: Array with #{data.length} items"
        if data.length > 0 && data.first.is_a?(Hash)
          puts "📋 First item keys: #{data.first.keys.join(', ')}"
          # If it looks like user data, show some details
          if data.first.key?('name') || data.first.key?('email')
            puts "👥 Users found:"
            data.each_with_index do |user, index|
              name = user['name'] || user['display_name'] || 'Unknown'
              email = user['email'] || 'No email'
              role = user['role'] || user['type'] || 'Unknown role'
              availability = user['availability'] || 'Unknown status'
              puts "  #{index + 1}. #{name} (#{email}) - #{role} - #{availability}"
            end
          end
        end
      elsif data.is_a?(Hash)
        puts "📄 Response: Hash with keys: #{data.keys.join(', ')}"
        if data.key?('name') || data.key?('email')
          puts "👤 User: #{data['name']} (#{data['email']})"
        end
      else
        puts "📄 Response: #{response.body[0..200]}#{'...' if response.body.length > 200}"
      end
      return true
    when '401'
      puts "❌ UNAUTHORIZED - Invalid token"
    when '403'
      puts "⚠️  FORBIDDEN - Token valid but insufficient permissions"
    when '404'
      puts "❓ NOT FOUND - Endpoint doesn't exist or no access"
    else
      puts "❌ ERROR: #{response.body[0..200]}#{'...' if response.body.length > 200}"
    end
    
  rescue => e
    puts "💥 EXCEPTION: #{e.message}"
  end
  
  return false
end

# Test each token against each endpoint
tokens.each do |token_name, token_value|
  puts "\n" + "="*60
  puts "🧪 Testing #{token_name}: #{token_value}"
  puts "="*60
  
  successful_calls = 0
  
  endpoints.each do |endpoint|
    url = "#{API_BASE}#{endpoint}"
    success = test_api_call(url, token_value, token_name)
    successful_calls += 1 if success
  end
  
  puts "\n📊 Summary for #{token_name}:"
  puts "   Successful calls: #{successful_calls}/#{endpoints.length}"
  
  if successful_calls > 0
    puts "✅ This token works for some endpoints!"
  else
    puts "❌ This token doesn't work for any tested endpoints"
  end
end

puts "\n" + "="*60
puts "🏁 Testing completed!"
puts "="*60 