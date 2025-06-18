#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

puts "🔍 TESTING PROVIDED TOKENS AGAINST AZURE ENVIRONMENT"
puts "=" * 60

# Get configuration from environment variables
BASE_URL = ENV['CHATWOOT_API_BASE_URL'] || 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'

# Tokens provided by user
TEST_TOKENS = [
  { 
    name: "Admin Token", 
    token: ENV['CHATWOOT_ADMIN_TOKEN'] || "J8mwDmmcZbuYs6a672oT8TW6", 
    type: "user",
    user_id: ENV['CHATWOOT_ADMIN_USER_ID'] || "1"
  },
  { 
    name: "Platform Token", 
    token: ENV['CHATWOOT_PLATFORM_TOKEN'] || "eb7Mc8LxE44ErjsdgS67Aqz6", 
    type: "platform",
    user_id: nil
  }
]

puts "\n📋 CONFIGURATION:"
puts "   API Base URL: #{BASE_URL}"
puts "   Testing #{TEST_TOKENS.length} provided tokens"

TEST_TOKENS.each_with_index do |token_info, index|
  puts "   #{index + 1}. #{token_info[:name]}: #{token_info[:token][0..15]}...#{token_info[:token][-4..-1]}"
end

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
  when 'DELETE'
    request = Net::HTTP::Delete.new(uri)
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
      puts "      Role: #{profile['role'] || 'Not specified'}"
      return { success: true, token: token_info, profile: profile, headers: headers }
    rescue JSON::ParserError
      puts "      Response received but not JSON"
      return { success: true, token: token_info, profile: nil, headers: headers }
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

def test_accounts_access(working_auth)
  puts "\n🏢 Testing Accounts Access:"
  
  # Try different account IDs
  account_ids = [1, 2, 22]  # Common account IDs
  
  account_ids.each do |account_id|
    response = make_request('GET', "/api/v1/accounts/#{account_id}", working_auth[:headers])
    
    case response[:status]
    when 200
      puts "   ✅ SUCCESS - Account #{account_id} accessible"
      begin
        account = JSON.parse(response[:body])
        puts "      Account: #{account['name']}"
        puts "      ID: #{account['id']}"
        puts "      Status: #{account['status']}"
        
        # Set environment variables for this account
        ENV['CHATWOOT_ACCOUNT_ID'] = account['id'].to_s
        ENV['CHATWOOT_ACCOUNT_NAME'] = account['name']
        
        return { success: true, account: account, account_id: account['id'] }
      rescue JSON::ParserError
        puts "      Response received but not JSON"
      end
    when 401
      puts "   ❌ Account #{account_id}: Unauthorized"
    when 404
      puts "   ⚠️  Account #{account_id}: Not found"
    else
      puts "   ❌ Account #{account_id}: HTTP #{response[:status]}"
    end
  end
  
  return { success: false, error: "No accessible accounts found" }
end

def test_conversations_access(working_auth, account_id)
  puts "\n💬 Testing Conversations Access:"
  
  response = make_request('GET', "/api/v1/accounts/#{account_id}/conversations", working_auth[:headers])
  
  case response[:status]
  when 200
    puts "   ✅ SUCCESS - Conversations accessible"
    begin
      data = JSON.parse(response[:body])
      conversations = data['data'] || []
      puts "      Found #{conversations.length} conversations"
      
      if conversations.any?
        conv = conversations.first
        puts "      Latest: ID #{conv['id']} - #{conv['meta']['sender']['name'] rescue 'Unknown'}"
        puts "      Status: #{conv['status']}"
        puts "      Inbox: #{conv['inbox']['name'] rescue 'Unknown'}"
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

def test_inboxes_access(working_auth, account_id)
  puts "\n📥 Testing Inboxes Access:"
  
  response = make_request('GET', "/api/v1/accounts/#{account_id}/inboxes", working_auth[:headers])
  
  case response[:status]
  when 200
    puts "   ✅ SUCCESS - Inboxes accessible"
    begin
      data = JSON.parse(response[:body])
      inboxes = data['payload'] || []
      puts "      Found #{inboxes.length} inboxes"
      
      inboxes.each do |inbox|
        puts "      - #{inbox['name']} (ID: #{inbox['id']}) - #{inbox['channel_type']}"
      end
      
      return { success: true, inboxes: inboxes }
    rescue JSON::ParserError
      puts "      Response received but not JSON"
      return { success: true, inboxes: [] }
    end
  when 401
    puts "   ❌ FAILED - Unauthorized access to inboxes"
    return { success: false, error: "Unauthorized" }
  when 404
    puts "   ❌ FAILED - Inboxes endpoint not found"
    return { success: false, error: "Endpoint not found" }
  else
    puts "   ❌ FAILED - HTTP #{response[:status]}"
    return { success: false, error: "HTTP #{response[:status]}" }
  end
end

# Test all tokens and authentication methods
puts "\n🔐 TESTING PROVIDED TOKENS:"

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
      puts "\n🔍 Testing additional endpoints with working authentication..."
      
      accounts_result = test_accounts_access(result)
      
      if accounts_result[:success]
        account_id = accounts_result[:account_id]
        conversations_result = test_conversations_access(result, account_id)
        inboxes_result = test_inboxes_access(result, account_id)
        
        # Store working token info
        working_tokens << {
          token: token_info,
          auth_method: auth_method[:name],
          headers: auth_method[:headers],
          profile: result[:profile],
          account: accounts_result[:account],
          conversations: conversations_result[:conversations],
          inboxes: inboxes_result[:inboxes]
        }
      end
      
      break  # Found working method for this token, move to next token
    end
  end
  
  if !token_working
    puts "\n   ❌ No working authentication methods for this token"
  end
end

puts "\n" + "=" * 60
puts "🎯 PROVIDED TOKENS TEST SUMMARY"
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
    
    if working_token[:inboxes]
      puts "   Inboxes: #{working_token[:inboxes].length} found"
    end
    puts ""
  end
  
  # Update environment variables for the first working token
  if working_tokens.any?
    best_token = working_tokens.first
    puts "🚀 UPDATING ENVIRONMENT VARIABLES:"
    puts "   export CHATWOOT_ACCOUNT_ID=#{best_token[:account]['id'] if best_token[:account]}"
    puts "   export CHATWOOT_ACCOUNT_NAME=\"#{best_token[:account]['name'] if best_token[:account]}\""
    puts "   export CHATWOOT_USER_TOKEN=#{best_token[:token][:token]}"
    if best_token[:profile]
      puts "   export CHATWOOT_USER_EMAIL=#{best_token[:profile]['email']}"
      puts "   export CHATWOOT_USER_ID=#{best_token[:profile]['id']}"
    end
    
    # Actually update the environment file
    env_updates = []
    env_updates << "export CHATWOOT_ACCOUNT_ID=#{best_token[:account]['id']}" if best_token[:account]
    env_updates << "export CHATWOOT_ACCOUNT_NAME=\"#{best_token[:account]['name']}\"" if best_token[:account]
    env_updates << "export CHATWOOT_USER_EMAIL=#{best_token[:profile]['email']}" if best_token[:profile]
    
    if env_updates.any?
      File.open('azure_database_config.env', 'a') do |f|
        f.puts "\n# Updated from successful token test - #{Time.now}"
        env_updates.each { |update| f.puts update }
      end
      puts "\n✅ Environment variables added to azure_database_config.env"
    end
    
    puts ""
    puts "🎯 READY FOR SMS WEBSOCKET TESTS!"
    puts "   1. Source updated environment: source azure_database_config.env"
    puts "   2. Run SMS test: ruby live_websocket_sms_test_auto.rb"
    puts "   3. Run multi-user test: ruby comprehensive_websocket_multi_user_test.rb"
  end
else
  puts "❌ FAILURE: No working authentication methods found"
  puts ""
  puts "🔧 TROUBLESHOOTING STEPS:"
  puts "1. Verify tokens are current and not expired"
  puts "2. Check if tokens are for the correct environment"
  puts "3. Verify API server is running and accessible"
  puts ""
  puts "💡 TOKENS TESTED:"
  TEST_TOKENS.each do |token|
    puts "   - #{token[:name]}: #{token[:token]}"
  end
end

puts "\n📊 Environment Status:"
puts "   API URL: #{BASE_URL}"
puts "   Test completed at: #{Time.now}" 