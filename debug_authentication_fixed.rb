#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

puts "🔍 CHATWOOT AUTHENTICATION SYSTEM - CORRECTED ANALYSIS"
puts "=" * 70

# Configuration
BASE_URL = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'

# Valid tokens from database analysis
VALID_TOKENS = [
  { 
    name: "Platform App Token", 
    token: "SamnuRSUjB4ZpktAqhLqxjeZ", 
    type: "platform",
    owner: "Super Admin Platform App"
  },
  { 
    name: "Platform App Token 2", 
    token: "NKXxMhyS5hcreJbu", 
    type: "platform",
    owner: "Storefront Platform App"
  },
  { 
    name: "Platform App Token 3", 
    token: "eb7Mc8LxE44Erjsd", 
    type: "platform",
    owner: "Stable API Platform App"
  },
  { 
    name: "Super Admin User Token", 
    token: "J8mwDmmcZbuYs6a672oT8TW6", 
    type: "user",
    owner: "Stable API Admin"
  }
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
          puts "   Data: #{data['name'] || data['email'] || data.inspect[0..100]}"
        elsif data.is_a?(Array)
          puts "   Response: Array with #{data.length} items"
          if data.length > 0 && data.first.is_a?(Hash)
            puts "   First item keys: #{data.first.keys.join(', ')}"
          end
        end
      rescue JSON::ParserError
        puts "   Response: #{response.body[0..100]}..."
      end
      
      return { success: true, method: method_name, response: response, data: data }
      
    when 401
      puts "   ❌ UNAUTHORIZED - Invalid token or wrong auth method"
      
    when 403
      puts "   ❌ FORBIDDEN - Token valid but insufficient permissions"
      
    when 404
      puts "   ❌ NOT FOUND - Endpoint doesn't exist"
      
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
  puts "\n" + "="*60
  puts "TESTING: #{token_info[:name]} (#{token_info[:type]})"
  puts "Owner: #{token_info[:owner]}"
  puts "="*60
  
  token = token_info[:token]
  
  # Correct endpoints based on routes analysis
  if token_info[:type] == "platform"
    endpoints = [
      "#{BASE_URL}/platform/api/v1/accounts",      # GET index - should work
      "#{BASE_URL}/platform/api/v1/agent_bots"     # GET index - should work
    ]
  else
    endpoints = [
      "#{BASE_URL}/api/v1/profile",                # GET profile - should work for user tokens
      "#{BASE_URL}/api/v1/accounts"                # GET accounts - should work for user tokens
    ]
  end
  
  successful_methods = []
  
  endpoints.each do |endpoint|
    puts "\n📡 Testing endpoint: #{endpoint}"
    
    # Method 1: Legacy api_access_token header (primary method)
    result1 = test_authentication_method(
      endpoint, 
      token, 
      "api_access_token header",
      { 'api_access_token' => token }
    )
    successful_methods << result1 if result1[:success]
    
    # Method 2: HTTP_API_ACCESS_TOKEN header (nginx compatibility)
    result2 = test_authentication_method(
      endpoint, 
      token, 
      "HTTP_API_ACCESS_TOKEN header",
      { 'HTTP_API_ACCESS_TOKEN' => token }
    )
    successful_methods << result2 if result2[:success]
    
    # Method 3: Authorization Bearer header (newer standard)
    result3 = test_authentication_method(
      endpoint, 
      token, 
      "Authorization Bearer",
      { 'Authorization' => "Bearer #{token}" }
    )
    successful_methods << result3 if result3[:success]
  end
  
  return successful_methods
end

# Main testing loop
puts "\n🚀 Starting corrected authentication testing..."

all_successful_methods = []

VALID_TOKENS.each do |token_info|
  successful_methods = test_token_with_all_methods(token_info)
  all_successful_methods.concat(successful_methods)
end

# Summary
puts "\n" + "="*70
puts "CORRECTED AUTHENTICATION ANALYSIS SUMMARY"
puts "="*70

if all_successful_methods.any?
  puts "\n✅ WORKING AUTHENTICATION METHODS FOUND:"
  
  all_successful_methods.each_with_index do |method, index|
    puts "\n#{index + 1}. #{method[:method]}"
    puts "   Status: #{method[:response].code}"
    puts "   Endpoint: #{method[:response].uri}"
    if method[:data]
      if method[:data].is_a?(Hash)
        puts "   Response: #{method[:data]['name'] || method[:data]['email'] || 'Hash data'}"
      elsif method[:data].is_a?(Array)
        puts "   Response: Array with #{method[:data].length} items"
      end
    end
  end
  
  # Group by method type
  method_counts = all_successful_methods.group_by { |m| m[:method] }
  
  puts "\n📊 SUCCESS RATE BY METHOD:"
  method_counts.each do |method, results|
    puts "   #{method}: #{results.length} successful calls"
  end
  
  puts "\n🎯 RECOMMENDED AUTHENTICATION METHOD:"
  if method_counts["api_access_token header"]
    puts "   ✅ Use 'api_access_token' header (Chatwoot standard)"
    puts "   Example: curl -H 'api_access_token: YOUR_TOKEN' URL"
  elsif method_counts["Authorization Bearer"]
    puts "   ✅ Use 'Authorization: Bearer TOKEN' header (HTTP standard)"
    puts "   Example: curl -H 'Authorization: Bearer YOUR_TOKEN' URL"
  end
  
else
  puts "\n❌ NO WORKING AUTHENTICATION METHODS FOUND"
  puts "\nThis indicates issues with:"
  puts "   1. Token permissions/associations"
  puts "   2. Platform app permissible resources"
  puts "   3. User account associations"
  puts "   4. API endpoint configuration"
end

puts "\n🔍 KEY FINDINGS:"

puts "\nFrom database analysis:"
puts "   • Platform tokens exist and are valid in database"
puts "   • User tokens exist but may lack account associations"
puts "   • Account 22 was not found in database"
puts "   • Platform apps need 'permissible' resources to access data"

puts "\nFrom routes analysis:"
puts "   • Platform API endpoints: /platform/api/v1/*"
puts "   • User API endpoints: /api/v1/*"
puts "   • Platform tokens need platform_app_permissibles for access"
puts "   • User tokens need proper account associations"

if all_successful_methods.any?
  puts "\n💡 NEXT STEPS FOR WORKING TOKENS:"
  puts "   1. Use the working authentication method identified above"
  puts "   2. For platform tokens: Create permissible resources as needed"
  puts "   3. For user tokens: Ensure proper account associations"
  puts "   4. Test specific API endpoints you need"
else
  puts "\n💡 TROUBLESHOOTING STEPS:"
  puts "   1. Check platform_app_permissibles table for platform tokens"
  puts "   2. Check account_users table for user token associations"
  puts "   3. Create test accounts/resources via Rails console"
  puts "   4. Verify token ownership in access_tokens table"
end

puts "\n" + "="*70
puts "Corrected authentication testing complete."
puts "="*70 