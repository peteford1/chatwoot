#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

puts "🔍 Deep Testing Chatwoot API Tokens..."

# API tokens to test
tokens = {
  "CHATWOOT_ADMIN_API_TOKEN" => "YkT9vdgc2UFZ2kgMhPdEaajT",
  "CHATWOOT_API_TOKEN" => "zEGFZ3658VdbbvkCTrpy8C5z"
}

# API base URL
API_BASE = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'

def test_api_call_with_headers(url, token, token_name, headers = {})
  puts "\n📡 Testing: #{url}"
  puts "🔑 Token: #{token_name}"
  
  begin
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 15
    
    request = Net::HTTP::Get.new(uri)
    
    # Try different header formats
    request['api_access_token'] = token
    request['Authorization'] = "Bearer #{token}"
    request['X-API-Key'] = token
    request['Content-Type'] = 'application/json'
    
    # Add any additional headers
    headers.each { |key, value| request[key] = value }
    
    response = http.request(request)
    
    puts "📊 Response Code: #{response.code}"
    puts "📋 Response Headers: #{response.to_hash.select { |k, v| k.downcase.include?('auth') || k.downcase.include?('token') || k.downcase.include?('api') }}"
    
    case response.code
    when '200'
      puts "✅ SUCCESS!"
      begin
        data = JSON.parse(response.body)
        puts "📄 Response Data:"
        if data.is_a?(Hash)
          data.each { |key, value| puts "  #{key}: #{value.is_a?(String) ? value[0..100] : value}" }
        elsif data.is_a?(Array)
          puts "  Array with #{data.length} items"
          if data.length > 0
            puts "  First item: #{data.first}"
          end
        end
      rescue JSON::ParserError
        puts "📄 Raw Response: #{response.body[0..300]}"
      end
      return true
    when '401'
      puts "❌ UNAUTHORIZED - Invalid token"
      puts "📄 Response: #{response.body}"
    when '403'
      puts "⚠️  FORBIDDEN - Token valid but insufficient permissions"
      puts "📄 Response: #{response.body}"
    when '404'
      puts "❓ NOT FOUND"
      puts "📄 Response: #{response.body}"
    else
      puts "❌ ERROR (#{response.code}): #{response.body[0..200]}"
    end
    
  rescue => e
    puts "💥 EXCEPTION: #{e.message}"
  end
  
  return false
end

# Test different endpoint patterns
tokens.each do |token_name, token_value|
  puts "\n" + "="*80
  puts "🧪 Deep Testing #{token_name}: #{token_value}"
  puts "="*80
  
  # Try to get profile/user info
  test_api_call_with_headers("#{API_BASE}/api/v1/profile", token_value, token_name)
  
  # Try different account IDs (common ones are 1, 2, 3)
  (1..5).each do |account_id|
    puts "\n🏢 Testing Account ID: #{account_id}"
    
    # Try agents endpoint for this account
    test_api_call_with_headers("#{API_BASE}/api/v1/accounts/#{account_id}/agents", token_value, token_name)
    
    # Try conversations endpoint
    test_api_call_with_headers("#{API_BASE}/api/v1/accounts/#{account_id}/conversations", token_value, token_name)
    
    # Try contacts endpoint
    test_api_call_with_headers("#{API_BASE}/api/v1/accounts/#{account_id}/contacts", token_value, token_name)
  end
  
  # Try platform API endpoints
  puts "\n🔧 Testing Platform API endpoints:"
  test_api_call_with_headers("#{API_BASE}/platform/api/v1/users/1", token_value, token_name)
  test_api_call_with_headers("#{API_BASE}/platform/api/v1/accounts/1", token_value, token_name)
  
  # Try without account context
  puts "\n🌐 Testing Global endpoints:"
  test_api_call_with_headers("#{API_BASE}/api/v1/accounts", token_value, token_name)
  
  puts "\n" + "-"*60
end

puts "\n🏁 Deep testing completed!" 