#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

# NEW STABLE PLATFORM TOKEN (never expires)
STABLE_TOKEN = "eb7Mc8LxE44ErjsdgS67Aqz6"
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

puts "🔍 TESTING NEW STABLE PLATFORM TOKEN"
puts "=" * 60
puts "Token: #{STABLE_TOKEN}"
puts "Base URL: #{BASE_URL}"
puts "This token NEVER EXPIRES and has platform-level permissions!"
puts

# Test various API endpoints to find what works
test_endpoints = [
  # Platform API endpoints
  ['GET', '/platform/api/v1/accounts'],
  ['GET', '/platform/api/v1/users'],
  
  # Regular API endpoints  
  ['GET', "/api/v1/accounts/#{ACCOUNT_ID}"],
  ['GET', "/api/v1/accounts/#{ACCOUNT_ID}/agents"],
  ['GET', "/api/v1/accounts/#{ACCOUNT_ID}/conversations"],
  ['GET', "/api/v1/accounts/#{ACCOUNT_ID}/contacts"],
  ['GET', "/api/v1/accounts/#{ACCOUNT_ID}/inboxes"],
  
  # Profile endpoints
  ['GET', '/api/v1/profile'],
  
  # Widget endpoints (might work with platform token)
  ['GET', '/api/v1/widget/config'],
  
  # Super admin endpoints (if platform token has super admin access)
  ['GET', '/super_admin/accounts'],
  ['GET', '/super_admin/users']
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
puts "🎯 SUMMARY FOR STABLE TOKEN: #{STABLE_TOKEN}"
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

puts "🔑 KEY FINDINGS:"
puts "   • Token: #{STABLE_TOKEN}"
puts "   • Type: Platform Token (NEVER EXPIRES)"
puts "   • Created: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
puts "   • Working endpoints: #{working_endpoints.length}"
puts "   • Failed endpoints: #{failed_endpoints.length}"

if working_endpoints.any?
  puts "\n🎉 SUCCESS! This stable token works for #{working_endpoints.length} endpoints."
  puts "Applications can use this token reliably without worrying about expiration."
else
  puts "\n⚠️  No endpoints working. May need to check token permissions or API configuration."
end

puts "\n📝 SAVE THIS TOKEN:"
puts "CHATWOOT_STABLE_API_TOKEN=#{STABLE_TOKEN}"
puts "=" * 60 