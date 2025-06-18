#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

# STABLE PLATFORM TOKEN (from production documentation)
STABLE_TOKEN = "PDcyku9tpAYnNytixsfmoCHo"
BASE_URL = "https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
ACCOUNT_ID = 1

def make_api_request(method, endpoint, token, body = nil)
  uri = URI("#{BASE_URL}#{endpoint}")
  
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  
  case method.upcase
  when 'GET'
    request = Net::HTTP::Get.new(uri)
  when 'POST'
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = body if body
  end
  
  request['api_access_token'] = token
  
  response = http.request(request)
  puts "#{method} #{endpoint}: #{response.code} #{response.message}"
  
  if response.code.to_i < 400
    puts "✅ SUCCESS"
    if response.body && !response.body.empty?
      data = JSON.parse(response.body) rescue response.body
      if data.is_a?(Hash) && data['data']
        puts "   Found #{data['data'].length} items" if data['data'].is_a?(Array)
      elsif data.is_a?(Array)
        puts "   Found #{data.length} items"
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

puts "🔍 TESTING STABLE PLATFORM TOKEN"
puts "=" * 50
puts "Token: #{STABLE_TOKEN}"
puts "Base URL: #{BASE_URL}"
puts

# Test 1: Platform API (should work)
puts "1️⃣ Testing Platform API endpoints..."
make_api_request('GET', '/platform/api/v1/accounts', STABLE_TOKEN)

# Test 2: Regular API (might have limited access)
puts "\n2️⃣ Testing Regular API endpoints..."
make_api_request('GET', "/api/v1/accounts/#{ACCOUNT_ID}/agents", STABLE_TOKEN)

# Test 3: Conversations API
puts "\n3️⃣ Testing Conversations API..."
make_api_request('GET', "/api/v1/accounts/#{ACCOUNT_ID}/conversations", STABLE_TOKEN)

# Test 4: Profile API
puts "\n4️⃣ Testing Profile API..."
make_api_request('GET', '/api/v1/profile', STABLE_TOKEN)

puts "\n" + "=" * 50
puts "🎯 CONCLUSION:"
puts "If Platform API works, this token is STABLE and NON-EXPIRING!"
puts "This is the token applications should use for reliable API access."
puts "=" * 50 