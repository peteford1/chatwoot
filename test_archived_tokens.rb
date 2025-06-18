#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

puts "🔍 TESTING ARCHIVED TOKENS FROM DOCUMENTATION"
puts "=" * 60

# Get configuration from environment variables
BASE_URL = ENV['CHATWOOT_API_BASE_URL'] || 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'

# Archived tokens from documentation
ARCHIVED_TOKENS = [
  { 
    name: "Archived Platform Token", 
    token: "YkT9vdgc2UFZ2kgMhPdEaajT", 
    type: "platform"
  },
  { 
    name: "Archived Admin Token", 
    token: "0212af10d6c85e3f692325e0", 
    type: "user"
  },
  {
    name: "Current Admin Token (from env)",
    token: "J8mwDmmcZbuYs6a672oT8TW6",
    type: "user"
  },
  {
    name: "Current Platform Token (from env)",
    token: "eb7Mc8LxE44ErjsdgS67Aqz6",
    type: "platform"
  }
]

puts "\n📋 CONFIGURATION:"
puts "   API Base URL: #{BASE_URL}"
puts "   Testing #{ARCHIVED_TOKENS.length} archived tokens"

ARCHIVED_TOKENS.each_with_index do |token_info, index|
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

# Test all archived tokens
puts "\n🔐 TESTING ARCHIVED TOKENS:"

successful_authentications = []
working_tokens = []

ARCHIVED_TOKENS.each do |token_info|
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
        
        # Store working token info
        working_tokens << {
          token: token_info,
          auth_method: auth_method[:name],
          headers: auth_method[:headers],
          profile: result[:profile],
          account: accounts_result[:account]
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
puts "🎯 ARCHIVED TOKENS TEST SUMMARY"
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
    env_content = <<~ENV
      
      # ============================================================================
      # WORKING ARCHIVED TOKEN - #{Time.now}
      # ============================================================================
      
      # Working token: #{best_token[:token][:name]}
      export CHATWOOT_USER_TOKEN="#{best_token[:token][:token]}"
      export CHATWOOT_ADMIN_TOKEN="#{best_token[:token][:token]}"
    ENV
    
    if best_token[:account]
      env_content += "export CHATWOOT_ACCOUNT_ID=#{best_token[:account]['id']}\n"
      env_content += "export CHATWOOT_ACCOUNT_NAME=\"#{best_token[:account]['name']}\"\n"
    end
    
    if best_token[:profile]
      env_content += "export CHATWOOT_USER_EMAIL=\"#{best_token[:profile]['email']}\"\n"
      env_content += "export CHATWOOT_USER_ID=#{best_token[:profile]['id']}\n"
    end
    
    File.open('azure_database_config.env', 'a') { |f| f.write(env_content) }
    puts "\n✅ Environment variables added to azure_database_config.env"
    
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
  puts "1. All archived tokens appear to be expired"
  puts "2. Need to generate fresh tokens from the Azure environment"
  puts "3. Consider using Rails console if Redis issues can be resolved"
  puts ""
  puts "💡 TOKENS TESTED:"
  ARCHIVED_TOKENS.each do |token|
    puts "   - #{token[:name]}: #{token[:token]}"
  end
end

puts "\n📊 Environment Status:"
puts "   API URL: #{BASE_URL}"
puts "   Test completed at: #{Time.now}" 