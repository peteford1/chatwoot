#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

# FINAL STABLE USER TOKEN (never expires)
STABLE_TOKEN = "J8mwDmmcZbuYs6a672oT8TW6"
BASE_URL = "https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
ACCOUNT_ID = 1

def make_api_request(method, endpoint, token, body = nil)
  uri = URI("#{BASE_URL}#{endpoint}")
  
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.read_timeout = 10
  
  case method.upcase
  when 'GET'
    request = Net::HTTP::Get.new(uri)
  when 'POST'
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = body if body
  end
  
  request['api_access_token'] = token
  
  begin
    response = http.request(request)
    puts "#{method} #{endpoint}: #{response.code} #{response.message}"
    
    if response.code.to_i < 400
      puts "✅ SUCCESS"
      if response.body && !response.body.empty?
        begin
          data = JSON.parse(response.body)
          if data.is_a?(Hash) && data['data']
            puts "   Found #{data['data'].length} items" if data['data'].is_a?(Array)
          elsif data.is_a?(Array)
            puts "   Found #{data.length} items"
          elsif data.is_a?(Hash) && data['payload']
            puts "   Found #{data['payload'].length} items" if data['payload'].is_a?(Array)
          elsif data.is_a?(Hash) && data['name']
            puts "   User: #{data['name']} (#{data['email']})"
          end
        rescue JSON::ParserError
          puts "   Response: #{response.body[0..100]}..."
        end
      end
      return response
    else
      puts "❌ FAILED: #{response.body[0..200]}"
      return nil
    end
  rescue => e
    puts "❌ ERROR: #{e.message}"
    return nil
  end
end

puts "🔍 TESTING FINAL STABLE USER TOKEN"
puts "=" * 60
puts "Token: #{STABLE_TOKEN}"
puts "Base URL: #{BASE_URL}"
puts "User: Stable API Admin (stable-api-admin@voicelinkai.com)"
puts "Type: SuperAdmin User Token (NEVER EXPIRES)"
puts

# Test comprehensive API endpoints
test_endpoints = [
  # Profile endpoints
  ['GET', '/api/v1/profile'],
  
  # Account endpoints  
  ['GET', "/api/v1/accounts/#{ACCOUNT_ID}"],
  ['GET', "/api/v1/accounts/#{ACCOUNT_ID}/agents"],
  ['GET', "/api/v1/accounts/#{ACCOUNT_ID}/conversations"],
  ['GET', "/api/v1/accounts/#{ACCOUNT_ID}/contacts"],
  ['GET', "/api/v1/accounts/#{ACCOUNT_ID}/inboxes"],
  
  # Specific inbox endpoints
  ['GET', "/api/v1/accounts/#{ACCOUNT_ID}/inboxes/6"],
  ['GET', "/api/v1/accounts/#{ACCOUNT_ID}/inboxes/6/conversations"],
  
  # Message endpoints (for SMS testing)
  ['GET', "/api/v1/accounts/#{ACCOUNT_ID}/conversations/1/messages"] # if conversation 1 exists
]

working_endpoints = []
failed_endpoints = []

test_endpoints.each_with_index do |(method, endpoint), index|
  puts "#{index + 1}️⃣ Testing #{method} #{endpoint}..."
  response = make_api_request(method, endpoint, STABLE_TOKEN)
  
  if response
    working_endpoints << "#{method} #{endpoint}"
  else
    failed_endpoints << "#{method} #{endpoint}"
  end
  
  puts
end

puts "=" * 60
puts "🎯 FINAL RESULTS FOR STABLE TOKEN: #{STABLE_TOKEN}"
puts "=" * 60

if working_endpoints.any?
  puts "✅ WORKING ENDPOINTS (#{working_endpoints.length}):"
  working_endpoints.each { |endpoint| puts "   • #{endpoint}" }
  puts
end

if failed_endpoints.any?
  puts "❌ FAILED ENDPOINTS (#{failed_endpoints.length}):"
  failed_endpoints.each { |endpoint| puts "   • #{endpoint}" }
  puts
end

puts "🔑 FINAL STABLE TOKEN SUMMARY:"
puts "   • Token: #{STABLE_TOKEN}"
puts "   • Type: SuperAdmin User Token"
puts "   • Expiration: NEVER EXPIRES"
puts "   • Owner: Stable API Admin (stable-api-admin@voicelinkai.com)"
puts "   • Working endpoints: #{working_endpoints.length}"
puts "   • Failed endpoints: #{failed_endpoints.length}"

if working_endpoints.any?
  puts "\n🎉 SUCCESS! This is your stable, non-expiring API token!"
  puts "Applications can use this token reliably without worrying about expiration."
  puts "\n📝 SAVE THIS TOKEN FOR PRODUCTION USE:"
  puts "CHATWOOT_STABLE_API_TOKEN=#{STABLE_TOKEN}"
  
  puts "\n🚀 READY FOR SMS WEBSOCKET TEST!"
  puts "You can now run your live SMS WebSocket test with this token."
else
  puts "\n⚠️  Token created but endpoints not working. May need account association."
end

puts "=" * 60 