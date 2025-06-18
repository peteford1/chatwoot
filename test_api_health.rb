#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

puts "🔍 CHATWOOT API HEALTH CHECK"
puts "=" * 40

# Get configuration from environment variables
BASE_URL = ENV['CHATWOOT_API_BASE_URL'] || 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'

puts "\n📋 CONFIGURATION:"
puts "   API Base URL: #{BASE_URL}"

def make_request(method, path, headers = {}, body = nil)
  uri = URI("#{BASE_URL}#{path}")
  
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  http.read_timeout = 30
  
  case method.upcase
  when 'GET'
    request = Net::HTTP::Get.new(uri)
  when 'POST'
    request = Net::HTTP::Post.new(uri)
    request.body = body if body
  end
  
  # Set headers
  headers.each { |key, value| request[key] = value }
  request['Content-Type'] = 'application/json' if body
  
  begin
    response = http.request(request)
    {
      status: response.code.to_i,
      body: response.body,
      headers: response.to_hash
    }
  rescue => e
    {
      status: 0,
      body: "Connection error: #{e.message}",
      headers: {}
    }
  end
end

def test_api_health
  puts "\n🏥 Testing API Health:"
  
  # Test basic API health endpoint
  response = make_request('GET', '/api/v1/profile')
  
  case response[:status]
  when 200
    puts "   ✅ SUCCESS - API is responding"
    begin
      profile = JSON.parse(response[:body])
      puts "      Response: Valid JSON received"
    rescue JSON::ParserError
      puts "      Response: Non-JSON response (might be HTML)"
    end
    return true
  when 401
    puts "   ⚠️  EXPECTED - API requires authentication (401 Unauthorized)"
    puts "      This is normal - the API is working but needs a token"
    return true
  when 404
    puts "   ❌ FAILED - API endpoint not found (404)"
    return false
  when 0
    puts "   ❌ FAILED - Connection error"
    puts "      #{response[:body]}"
    return false
  else
    puts "   ⚠️  UNEXPECTED - HTTP #{response[:status]}"
    puts "      #{response[:body][0..200]}"
    return false
  end
end

def test_public_endpoints
  puts "\n🌐 Testing Public Endpoints:"
  
  # Test if there are any public endpoints
  public_endpoints = [
    '/api/v1/widget/config',
    '/api/v1/public',
    '/health',
    '/'
  ]
  
  public_endpoints.each do |endpoint|
    response = make_request('GET', endpoint)
    status_emoji = case response[:status]
                   when 200..299 then "✅"
                   when 400..499 then "⚠️"
                   else "❌"
                   end
    
    puts "   #{status_emoji} #{endpoint}: HTTP #{response[:status]}"
  end
end

# Run tests
puts "\n🔍 TESTING API CONNECTIVITY:"

api_working = test_api_health
test_public_endpoints

puts "\n" + "=" * 40
puts "🎯 API HEALTH CHECK SUMMARY"
puts "=" * 40

if api_working
  puts "✅ SUCCESS: Azure API is accessible and responding"
  puts ""
  puts "🔧 NEXT STEPS:"
  puts "   The API is working, but we need to fix the Redis configuration"
  puts "   to run Rails commands and get user tokens."
  puts ""
  puts "   Options:"
  puts "   1. Fix Redis configuration in Rails"
  puts "   2. Use existing tokens from previous tests"
  puts "   3. Create tokens via direct database connection"
  puts ""
  puts "🚀 READY FOR AUTHENTICATION TESTS!"
  puts "   Once we have tokens, we can test authentication."
else
  puts "❌ FAILURE: Azure API is not accessible"
  puts ""
  puts "🔧 TROUBLESHOOTING STEPS:"
  puts "1. Check network connectivity:"
  puts "   ping chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
  puts ""
  puts "2. Verify API server is running:"
  puts "   curl -I #{BASE_URL}/api/v1/profile"
  puts ""
  puts "3. Check Azure Container App status in Azure Portal"
end

puts "\n📊 Environment Status:"
puts "   API URL: #{BASE_URL}"
puts "   Test completed at: #{Time.now}" 