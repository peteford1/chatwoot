#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

puts "🔍 CHATWOOT AUTHENTICATION TEST - HARDCODED TOKENS"
puts "=" * 60

# Get configuration from environment variables
BASE_URL = ENV['CHATWOOT_API_BASE_URL'] || 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'

# Tokens found in previous database analysis
TEST_TOKENS = [
  { 
    name: "Platform Token 1", 
    token: "SamnuRSUjB4ZpktAqhLqxjeZ", 
    type: "platform",
    account_id: 1  # From previous analysis
  },
  { 
    name: "Platform Token 2", 
    token: "NKXxMhyS5hcreJbu", 
    type: "platform",
    account_id: 1
  },
  { 
    name: "Platform Token 3", 
    token: "eb7Mc8LxE44Erjsd", 
    type: "platform",
    account_id: 1
  },
  { 
    name: "User Token 1", 
    token: "xMHQXEmNJYXRRUnXeb9s74Uu", 
    type: "user",
    account_id: 1
  },
  { 
    name: "User Token 2", 
    token: "xyoWbZdQ7UM8Dy65WisxUEnZ", 
    type: "user",
    account_id: 1
  }
]

puts "\n📋 CONFIGURATION:"
puts "   API Base URL: #{BASE_URL}"
puts "   Testing #{TEST_TOKENS.length} tokens from previous database analysis"

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

def test_authentication_method(token_info, method_name, headers)
  puts "\n🧪 Testing #{method_name} with #{token_info[:name]}:"
  
  # Test basic API health
  response = make_request('GET', '/api/v1/profile', headers)
  
  case response[:status]
  when 200
    puts "   ✅ SUCCESS - Authentication working"
    begin
      profile = JSON.parse(response[:body])
      puts "      User: #{profile['name']} (#{profile['email']})"
      puts "      ID: #{profile['id']}"
      return { success: true, token: token_info, profile: profile }
    rescue JSON::ParserError
      puts "      Response received but not JSON"
      return { success: true, token: token_info, profile: nil }
    end
  when 401
    puts "   ❌ FAILED - Invalid token (401 Unauthorized)"
    return { success: false, token: token_info, error: "Invalid token" }
  when 404
    puts "   ❌ FAILED - Endpoint not found (404)"
    return { success: false, token: token_info, error: "Endpoint not found" }
  when 0
    puts "   ❌ FAILED - Connection error"
    puts "      #{response[:body]}"
    return { success: false, token: token_info, error: "Connection error" }
  else
    puts "   ❌ FAILED - HTTP #{response[:status]}"
    puts "      #{response[:body][0..200]}"
    return { success: false, token: token_info, error: "HTTP #{response[:status]}" }
  end
end

def test_account_access(token_info, headers)
  puts "\n🏢 Testing Account Access with #{token_info[:name]}:"
  
  response = make_request('GET', "/api/v1/accounts/#{token_info[:account_id]}", headers)
  
  case response[:status]
  when 200
    puts "   ✅ SUCCESS - Account access working"
    begin
      account = JSON.parse(response[:body])
      puts "      Account: #{account['name']}"
      puts "      ID: #{account['id']}"
      puts "      Status: #{account['status']}"
      return { success: true, account: account }
    rescue JSON::ParserError
      puts "      Response received but not JSON"
      return { success: true, account: nil }
    end
  when 401
    puts "   ❌ FAILED - Unauthorized access to account"
    return { success: false, error: "Unauthorized" }
  when 404
    puts "   ❌ FAILED - Account not found"
    return { success: false, error: "Account not found" }
  else
    puts "   ❌ FAILED - HTTP #{response[:status]}"
    return { success: false, error: "HTTP #{response[:status]}" }
  end
end

def test_conversations_access(token_info, headers)
  puts "\n💬 Testing Conversations Access with #{token_info[:name]}:"
  
  response = make_request('GET', "/api/v1/accounts/#{token_info[:account_id]}/conversations", headers)
  
  case response[:status]
  when 200
    puts "   ✅ SUCCESS - Conversations access working"
    begin
      data = JSON.parse(response[:body])
      conversations = data['data'] || []
      puts "      Found #{conversations.length} conversations"
      
      if conversations.any?
        conv = conversations.first
        puts "      Latest: ID #{conv['id']} - #{conv['meta']['sender']['name'] rescue 'Unknown'}"
      end
      return { success: true, conversations: conversations }
    rescue JSON::ParserError
      puts "      Response received but not JSON"
      return { success: true, conversations: [] }
    end
  when 401
    puts "   ❌ FAILED - Unauthorized access to conversations"
    return { success: false, error: "Unauthorized" }
  when 404
    puts "   ❌ FAILED - Conversations endpoint not found"
    return { success: false, error: "Endpoint not found" }
  else
    puts "   ❌ FAILED - HTTP #{response[:status]}"
    return { success: false, error: "HTTP #{response[:status]}" }
  end
end

# Test all tokens and authentication methods
puts "\n🔐 TESTING AUTHENTICATION WITH HARDCODED TOKENS:"

successful_authentications = []
working_tokens = []

TEST_TOKENS.each do |token_info|
  puts "\n" + "=" * 50
  puts "🔑 Testing Token: #{token_info[:name]} (#{token_info[:type]})"
  puts "   Token: #{token_info[:token][0..15]}...#{token_info[:token][-4..-1]}"
  puts "=" * 50
  
  # Test all authentication methods for this token
  auth_methods = [
    { name: "api_access_token header", headers: { 'api_access_token' => token_info[:token] } },
    { name: "Authorization Bearer", headers: { 'Authorization' => "Bearer #{token_info[:token]}" } },
    { name: "HTTP_API_ACCESS_TOKEN", headers: { 'HTTP_API_ACCESS_TOKEN' => token_info[:token] } }
  ]
  
  token_working = false
  
  auth_methods.each do |auth_method|
    result = test_authentication_method(token_info, auth_method[:name], auth_method[:headers])
    
    if result[:success]
      successful_authentications << result
      token_working = true
      
      # Test additional endpoints with working method
      account_result = test_account_access(token_info, auth_method[:headers])
      conversations_result = test_conversations_access(token_info, auth_method[:headers])
      
      # Store working token info
      working_tokens << {
        token: token_info,
        auth_method: auth_method[:name],
        headers: auth_method[:headers],
        profile: result[:profile],
        account: account_result[:account],
        conversations: conversations_result[:conversations]
      }
      
      break  # Found working method for this token, move to next token
    end
  end
  
  if !token_working
    puts "\n   ❌ No working authentication methods for this token"
  end
end

puts "\n" + "=" * 60
puts "🎯 AUTHENTICATION TEST SUMMARY"
puts "=" * 60

if successful_authentications.any?
  puts "✅ SUCCESS: #{successful_authentications.length} working authentication(s) found"
  puts ""
  
  working_tokens.each_with_index do |working_token, index|
    puts "#{index + 1}. #{working_token[:token][:name]} (#{working_token[:token][:type]})"
    puts "   Method: #{working_token[:auth_method]}"
    puts "   Token: #{working_token[:token][:token]}"
    
    if working_token[:profile]
      puts "   User: #{working_token[:profile]['name']} (#{working_token[:profile]['email']})"
    end
    
    if working_token[:account]
      puts "   Account: #{working_token[:account]['name']} (ID: #{working_token[:account]['id']})"
    end
    
    if working_token[:conversations]
      puts "   Conversations: #{working_token[:conversations].length} found"
    end
    puts ""
  end
  
  # Set environment variables for the first working token
  if working_tokens.any?
    best_token = working_tokens.first
    puts "🚀 SETTING ENVIRONMENT VARIABLES FOR BEST TOKEN:"
    puts "   export CHATWOOT_ACCOUNT_ID=#{best_token[:account]['id'] if best_token[:account]}"
    puts "   export CHATWOOT_ACCOUNT_NAME=\"#{best_token[:account]['name'] if best_token[:account]}\""
    puts "   export CHATWOOT_USER_TOKEN=#{best_token[:token][:token]}"
    if best_token[:profile]
      puts "   export CHATWOOT_USER_EMAIL=#{best_token[:profile]['email']}"
      puts "   export CHATWOOT_USER_ID=#{best_token[:profile]['id']}"
    end
    puts ""
    puts "🎯 READY FOR SMS WEBSOCKET TESTS!"
    puts "   You can now run: ruby live_websocket_sms_test_auto.rb"
  end
else
  puts "❌ FAILURE: No working authentication methods found"
  puts ""
  puts "🔧 TROUBLESHOOTING STEPS:"
  puts "1. All tokens may have expired"
  puts "2. Account associations may have been removed"
  puts "3. Database may have been reset"
  puts ""
  puts "💡 NEXT STEPS:"
  puts "   Need to create fresh tokens via direct database connection"
  puts "   or fix Redis configuration to run Rails commands"
end

puts "\n📊 Environment Status:"
puts "   Database: #{ENV['POSTGRES_DATABASE']} @ #{ENV['POSTGRES_HOST']}"
puts "   Rails Env: #{ENV['RAILS_ENV']}"
puts "   API URL: #{BASE_URL}" 