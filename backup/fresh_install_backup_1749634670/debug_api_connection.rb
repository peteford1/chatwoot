#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'uri'

# Debug script to troubleshoot Chatwoot API connection issues
# This will help identify what's causing the errors

puts "🔧 Chatwoot API Connection Debug Tool"
puts "=" * 50

# Configuration - Update these
CHATWOOT_BASE_URL = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
GATEWAY_URL = 'https://voicelinkai-gateway.eastus.cloudapp.azure.com'
ACCOUNT_ID = 22
ADMIN_ACCESS_TOKEN = 'YOUR_ADMIN_ACCESS_TOKEN_HERE'  # Update this
PLATFORM_TOKEN = 'YkT9vdgc2UFZ2kgMhPdEaajT'

def test_connection(url, description)
  puts "\n🔍 Testing #{description}..."
  puts "   URL: #{url}"
  
  begin
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == 'https'
    http.open_timeout = 10
    http.read_timeout = 10
    
    request = Net::HTTP::Get.new(uri)
    response = http.request(request)
    
    puts "   Status: #{response.code} #{response.message}"
    puts "   Response size: #{response.body.length} bytes"
    
    if response.code.to_i == 200
      puts "   ✅ Connection successful"
    else
      puts "   ❌ Connection failed"
      puts "   Response: #{response.body[0..200]}..." if response.body.length > 0
    end
    
    return response.code.to_i.between?(200, 299)
    
  rescue => e
    puts "   ❌ Connection error: #{e.class} - #{e.message}"
    return false
  end
end

def test_api_with_auth(endpoint, token, token_type = "Bearer")
  puts "\n🔐 Testing authenticated endpoint..."
  puts "   Endpoint: #{endpoint}"
  puts "   Token type: #{token_type}"
  puts "   Token: #{token[0..10]}..." if token && token.length > 10
  
  begin
    uri = URI(endpoint)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == 'https'
    http.open_timeout = 15
    http.read_timeout = 15
    
    request = Net::HTTP::Get.new(uri)
    request['Content-Type'] = 'application/json'
    
    if token_type == "Bearer"
      request['Authorization'] = "Bearer #{token}"
    elsif token_type == "api_access_token"
      request['api_access_token'] = token
    end
    
    response = http.request(request)
    
    puts "   Status: #{response.code} #{response.message}"
    
    if response.code.to_i.between?(200, 299)
      parsed = JSON.parse(response.body) rescue nil
      puts "   ✅ Authentication successful"
      
      if parsed.is_a?(Hash)
        puts "   Response keys: #{parsed.keys.join(', ')}"
        if parsed['name']
          puts "   Account/Resource: #{parsed['name']}"
        end
      elsif parsed.is_a?(Array)
        puts "   Response: Array with #{parsed.length} items"
      end
      
      return true
    else
      puts "   ❌ Authentication failed"
      puts "   Response: #{response.body[0..300]}..."
      return false
    end
    
  rescue JSON::ParserError => e
    puts "   ⚠️  Non-JSON response: #{response.body[0..100]}..."
    return false
  rescue => e
    puts "   ❌ Request error: #{e.class} - #{e.message}"
    return false
  end
end

# Start debugging
puts "\n🚀 Starting API debugging process..."

# Test 1: Basic connectivity
puts "\n" + "="*50
puts "TEST 1: Basic Connectivity"
puts "="*50

backend_ok = test_connection(CHATWOOT_BASE_URL, "Chatwoot Backend")
gateway_ok = test_connection(GATEWAY_URL, "KrakenD Gateway")

# Test 2: Health endpoints (if available)
puts "\n" + "="*50
puts "TEST 2: Health Check Endpoints"
puts "="*50

test_connection("#{CHATWOOT_BASE_URL}/health", "Backend Health")
test_connection("#{GATEWAY_URL}/health", "Gateway Health")

# Test 3: Authentication tests
puts "\n" + "="*50
puts "TEST 3: Authentication Tests"
puts "="*50

if ADMIN_ACCESS_TOKEN != 'YOUR_ADMIN_ACCESS_TOKEN_HERE'
  puts "\n🔐 Testing Chatwoot API authentication..."
  
  # Test account access
  chatwoot_auth_ok = test_api_with_auth(
    "#{CHATWOOT_BASE_URL}/api/v1/accounts/#{ACCOUNT_ID}", 
    ADMIN_ACCESS_TOKEN, 
    "Bearer"
  )
  
  # Test inboxes endpoint
  if chatwoot_auth_ok
    test_api_with_auth(
      "#{CHATWOOT_BASE_URL}/api/v1/accounts/#{ACCOUNT_ID}/inboxes", 
      ADMIN_ACCESS_TOKEN, 
      "Bearer"
    )
  end
  
else
  puts "⚠️  Skipping Chatwoot auth test - please update ADMIN_ACCESS_TOKEN"
end

# Test Platform API
puts "\n🔐 Testing Platform API authentication..."
platform_auth_ok = test_api_with_auth(
  "#{GATEWAY_URL}/platform/api/v1/accounts/#{ACCOUNT_ID}", 
  PLATFORM_TOKEN, 
  "api_access_token"
)

# Test 4: Ruby environment
puts "\n" + "="*50
puts "TEST 4: Ruby Environment"
puts "="*50

puts "Ruby version: #{RUBY_VERSION}"
puts "Platform: #{RUBY_PLATFORM}"

required_libs = ['net/http', 'json', 'uri', 'openssl']
required_libs.each do |lib|
  begin
    require lib
    puts "✅ #{lib} available"
  rescue LoadError => e
    puts "❌ #{lib} missing: #{e.message}"
  end
end

# Test 5: SSL/TLS
puts "\n" + "="*50
puts "TEST 5: SSL/TLS Configuration"
puts "="*50

begin
  require 'openssl'
  puts "OpenSSL version: #{OpenSSL::OPENSSL_VERSION}"
  puts "SSL verify mode: #{OpenSSL::SSL::VERIFY_PEER}"
  puts "✅ SSL support available"
rescue => e
  puts "❌ SSL issue: #{e.message}"
end

# Summary and recommendations
puts "\n" + "="*50
puts "🎯 DEBUGGING SUMMARY & RECOMMENDATIONS"
puts "="*50

if !backend_ok
  puts "\n❌ ISSUE: Cannot connect to Chatwoot backend"
  puts "   Recommendations:"
  puts "   - Check if the server is running"
  puts "   - Verify the URL: #{CHATWOOT_BASE_URL}"
  puts "   - Test manually: curl -I #{CHATWOOT_BASE_URL}"
  puts "   - Check firewall/network restrictions"
end

if !gateway_ok
  puts "\n❌ ISSUE: Cannot connect to KrakenD gateway"
  puts "   Recommendations:"
  puts "   - Check if KrakenD container is running"
  puts "   - Verify the URL: #{GATEWAY_URL}"
  puts "   - Check Azure container status"
end

if ADMIN_ACCESS_TOKEN == 'YOUR_ADMIN_ACCESS_TOKEN_HERE'
  puts "\n⚠️  CONFIGURATION: Admin access token not configured"
  puts "   Steps to get token:"
  puts "   1. Login to Chatwoot dashboard"
  puts "   2. Go to Profile Settings → Access Token"
  puts "   3. Create new token and copy it"
  puts "   4. Update ADMIN_ACCESS_TOKEN in the script"
end

puts "\n📋 NEXT STEPS:"
puts "1. Fix any connection issues identified above"
puts "2. Update authentication tokens if needed"
puts "3. Re-run your original script"
puts "4. If still having issues, share the specific error messages"

puts "\n🔧 For additional help, run these manual tests:"
puts "curl -I #{CHATWOOT_BASE_URL}"
puts "curl -I #{GATEWAY_URL}"

if ADMIN_ACCESS_TOKEN != 'YOUR_ADMIN_ACCESS_TOKEN_HERE'
  puts "curl -H 'Authorization: Bearer #{ADMIN_ACCESS_TOKEN}' #{CHATWOOT_BASE_URL}/api/v1/accounts/#{ACCOUNT_ID}"
end 