#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

puts "🔍 CHATWOOT AUTHENTICATION SYSTEM ANALYSIS"
puts "=" * 60

# Configuration
BASE_URL = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
ACCOUNT_ID = 22

# Test tokens (all the ones we've tried)
TEST_TOKENS = [
  { name: "Platform Token 1", token: "baea8676c67aba47c08564ce", type: "platform" },
  { name: "Platform Token 2", token: "SamnuRSUjB4ZpktAqhLqxjeZ", type: "platform" },
  { name: "Platform Token 3", token: "NKXxMhyS5hWqGzCJdNfqxjeZ", type: "platform" },
  { name: "Platform Token 4", token: "PDcyku9tpAYnNytixsfmoCHo", type: "platform" },
  { name: "User Token 1", token: "xMHQXEmNJYXRRUnXeb9s74Uu", type: "user" },
  { name: "User Token 2", token: "xyoWbZdQ7UM8Dy65WisxUEnZ", type: "user" },
  { name: "User Token 3", token: "341179b44e238f00c018e9b8e98fcf620a9ff567745efd8d4dd7613b9b5a33f9", type: "user" },
  { name: "User Token 4", token: "J8mwDmmcZbuYs6a672oT8TW6", type: "user" }
]

def test_authentication_method(endpoint, token, method_name, headers)
  puts "\n   Testing #{method_name}..."
  puts "   Token: #{token[0..15]}..."
  
  begin
    uri = URI(endpoint)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 15
    
    request = Net::HTTP::Get.new(uri)
    request['Content-Type'] = 'application/json'
    
    # Apply headers
    headers.each { |key, value| request[key] = value }
    
    response = http.request(request)
    
    puts "   Status: #{response.code} #{response.message}"
    
    case response.code.to_i
    when 200..299
      puts "   ✅ SUCCESS with #{method_name}"
      
      begin
        data = JSON.parse(response.body)
        if data.is_a?(Hash)
          puts "   Response keys: #{data.keys.join(', ')}"
          puts "   Account/User: #{data['name'] || data['email'] || 'N/A'}"
        elsif data.is_a?(Array)
          puts "   Response: Array with #{data.length} items"
        end
      rescue JSON::ParserError
        puts "   Response: #{response.body[0..100]}..."
      end
      
      return { success: true, method: method_name, response: response }
      
    when 401
      puts "   ❌ UNAUTHORIZED - Invalid token or wrong auth method"
      
    when 403
      puts "   ❌ FORBIDDEN - Token valid but insufficient permissions"
      
    else
      puts "   ⚠️  #{response.code} - #{response.message}"
    end
    
    return { success: false, method: method_name, status: response.code }
    
  rescue => e
    puts "   ❌ ERROR: #{e.class} - #{e.message}"
    return { success: false, method: method_name, error: e.message }
  end
end

def test_token_with_all_methods(token_info)
  puts "\n" + "="*50
  puts "TESTING: #{token_info[:name]} (#{token_info[:type]})"
  puts "="*50
  
  token = token_info[:token]
  
  # Test endpoints based on token type
  if token_info[:type] == "platform"
    endpoints = [
      "#{BASE_URL}/platform/api/v1/accounts",
      "#{BASE_URL}/platform/api/v1/users"
    ]
  else
    endpoints = [
      "#{BASE_URL}/api/v1/profile",
      "#{BASE_URL}/api/v1/accounts/#{ACCOUNT_ID}",
      "#{BASE_URL}/api/v1/accounts/#{ACCOUNT_ID}/inboxes"
    ]
  end
  
  successful_methods = []
  
  endpoints.each do |endpoint|
    puts "\n📡 Testing endpoint: #{endpoint}"
    
    # Method 1: Legacy api_access_token header
    result1 = test_authentication_method(
      endpoint, 
      token, 
      "api_access_token header",
      { 'api_access_token' => token }
    )
    successful_methods << result1 if result1[:success]
    
    # Method 2: HTTP_API_ACCESS_TOKEN header (for nginx)
    result2 = test_authentication_method(
      endpoint, 
      token, 
      "HTTP_API_ACCESS_TOKEN header",
      { 'HTTP_API_ACCESS_TOKEN' => token }
    )
    successful_methods << result2 if result2[:success]
    
    # Method 3: Authorization Bearer header
    result3 = test_authentication_method(
      endpoint, 
      token, 
      "Authorization Bearer",
      { 'Authorization' => "Bearer #{token}" }
    )
    successful_methods << result3 if result3[:success]
    
    # Method 4: Authorization without Bearer
    result4 = test_authentication_method(
      endpoint, 
      token, 
      "Authorization (no Bearer)",
      { 'Authorization' => token }
    )
    successful_methods << result4 if result4[:success]
  end
  
  return successful_methods
end

# Main testing loop
puts "\n🚀 Starting comprehensive authentication testing..."

all_successful_methods = []

TEST_TOKENS.each do |token_info|
  successful_methods = test_token_with_all_methods(token_info)
  all_successful_methods.concat(successful_methods)
end

# Summary
puts "\n" + "="*60
puts "AUTHENTICATION ANALYSIS SUMMARY"
puts "="*60

if all_successful_methods.any?
  puts "\n✅ WORKING AUTHENTICATION METHODS FOUND:"
  
  all_successful_methods.each_with_index do |method, index|
    puts "\n#{index + 1}. #{method[:method]}"
    puts "   Status: #{method[:response].code}"
    puts "   Endpoint: #{method[:response].uri}"
  end
  
  # Group by method type
  method_counts = all_successful_methods.group_by { |m| m[:method] }
  
  puts "\n📊 SUCCESS RATE BY METHOD:"
  method_counts.each do |method, results|
    puts "   #{method}: #{results.length} successful calls"
  end
  
else
  puts "\n❌ NO WORKING AUTHENTICATION METHODS FOUND"
  puts "\nThis indicates a fundamental issue with:"
  puts "   1. Token validity/expiration"
  puts "   2. Authentication system configuration"
  puts "   3. API endpoint accessibility"
  puts "   4. Network/proxy issues"
end

puts "\n🔍 AUTHENTICATION SYSTEM DIAGNOSIS:"

puts "\nBased on Chatwoot source code analysis:"
puts "   • Chatwoot supports BOTH authentication methods:"
puts "     - Legacy: api_access_token header"
puts "     - Standard: Authorization: Bearer <token>"
puts "   • Platform tokens should work with /platform/api/* endpoints"
puts "   • User tokens should work with /api/v1/* endpoints"
puts "   • Tokens should NOT expire by design"

if all_successful_methods.empty?
  puts "\n💡 RECOMMENDED NEXT STEPS:"
  puts "   1. Check if Chatwoot backend is running properly"
  puts "   2. Verify database connectivity"
  puts "   3. Check if tokens exist in access_tokens table"
  puts "   4. Test direct database access to validate tokens"
  puts "   5. Check application logs for authentication errors"
  puts "   6. Verify KrakenD proxy configuration (if applicable)"
end

puts "\n" + "="*60
puts "Authentication testing complete."
puts "="*60 