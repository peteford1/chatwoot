#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

puts "🔍 TESTING VOICELINK ADMIN CREDENTIALS"
puts "=" * 60

# Configuration
BASE_URL = ENV['CHATWOOT_API_BASE_URL'] || 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
ADMIN_EMAIL = 'admin@voicelinkai.com'
ADMIN_PASSWORD = 'SuperAdmin!'

puts "\n📋 CONFIGURATION:"
puts "   API Base URL: #{BASE_URL}"
puts "   Admin Email: #{ADMIN_EMAIL}"
puts "   Admin Password: #{'*' * ADMIN_PASSWORD.length}"

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

# Test different authentication endpoints
auth_endpoints = [
  {
    name: "Admin Login",
    path: "/auth/sign_in",
    method: "POST",
    body: {
      email: ADMIN_EMAIL,
      password: ADMIN_PASSWORD
    }.to_json
  },
  {
    name: "API Login",
    path: "/api/v1/auth/sign_in",
    method: "POST", 
    body: {
      email: ADMIN_EMAIL,
      password: ADMIN_PASSWORD
    }.to_json
  },
  {
    name: "Platform Login",
    path: "/platform/api/v1/users/sign_in",
    method: "POST",
    body: {
      email: ADMIN_EMAIL,
      password: ADMIN_PASSWORD
    }.to_json
  },
  {
    name: "Super Admin Login",
    path: "/super_admin/sign_in",
    method: "POST",
    body: {
      email: ADMIN_EMAIL,
      password: ADMIN_PASSWORD
    }.to_json
  }
]

puts "\n🔐 TESTING AUTHENTICATION ENDPOINTS:"

successful_logins = []

auth_endpoints.each do |endpoint|
  puts "\n🧪 Testing #{endpoint[:name]}:"
  puts "   Endpoint: #{endpoint[:method]} #{endpoint[:path]}"
  
  response = make_request(endpoint[:method], endpoint[:path], {}, endpoint[:body])
  
  case response[:status]
  when 200, 201
    puts "   ✅ SUCCESS - Authentication successful!"
    
    begin
      data = JSON.parse(response[:body])
      
      # Look for token in different response formats
      token = nil
      user_data = nil
      
      if data['data'] && data['data']['access_token']
        token = data['data']['access_token']
        user_data = data['data']
      elsif data['access_token']
        token = data['access_token']
        user_data = data
      elsif data['token']
        token = data['token']
        user_data = data
      elsif data['auth_token']
        token = data['auth_token']
        user_data = data
      end
      
      if token
        puts "      Token: #{token[0..15]}...#{token[-4..-1]}"
        
        if user_data['email']
          puts "      User: #{user_data['name'] || 'Unknown'} (#{user_data['email']})"
        end
        
        if user_data['id']
          puts "      ID: #{user_data['id']}"
        end
        
        successful_logins << {
          endpoint: endpoint[:name],
          token: token,
          user_data: user_data,
          response: data
        }
      else
        puts "      ✅ Login successful but no token found in response"
        puts "      Response keys: #{data.keys.join(', ')}"
      end
      
    rescue JSON::ParserError
      puts "      ✅ Login successful but response not JSON"
      puts "      Response: #{response[:body][0..200]}"
    end
    
  when 401
    puts "   ❌ FAILED - Invalid credentials (401 Unauthorized)"
  when 404
    puts "   ⚠️  FAILED - Endpoint not found (404)"
  when 422
    puts "   ❌ FAILED - Validation error (422)"
    begin
      error_data = JSON.parse(response[:body])
      puts "      Error: #{error_data['message'] || error_data['error'] || 'Unknown validation error'}"
    rescue
      puts "      Error details: #{response[:body][0..200]}"
    end
  when 0
    puts "   ❌ FAILED - Connection error"
    puts "      #{response[:body]}"
  else
    puts "   ❌ FAILED - HTTP #{response[:status]}"
    puts "      #{response[:body][0..200]}"
  end
end

puts "\n" + "=" * 60
puts "🎯 VOICELINK CREDENTIALS TEST SUMMARY"
puts "=" * 60

if successful_logins.any?
  puts "✅ SUCCESS: #{successful_logins.length} successful authentication(s) found"
  puts ""
  
  successful_logins.each_with_index do |login, index|
    puts "#{index + 1}. #{login[:endpoint]}"
    puts "   Token: #{login[:token]}"
    
    if login[:user_data]['email']
      puts "   User: #{login[:user_data]['name'] || 'Unknown'} (#{login[:user_data]['email']})"
    end
    
    if login[:user_data]['id']
      puts "   ID: #{login[:user_data]['id']}"
    end
    
    puts ""
  end
  
  # Test the first working token
  if successful_logins.any?
    best_login = successful_logins.first
    puts "🧪 TESTING TOKEN AGAINST API ENDPOINTS:"
    
    # Test profile endpoint
    profile_response = make_request('GET', '/api/v1/profile', { 'api_access_token' => best_login[:token] })
    
    case profile_response[:status]
    when 200
      puts "   ✅ Profile endpoint works with token"
      begin
        profile = JSON.parse(profile_response[:body])
        puts "      Profile: #{profile['name']} (#{profile['email']})"
      rescue
        puts "      Profile data received"
      end
    when 401
      puts "   ❌ Token doesn't work with profile endpoint"
    else
      puts "   ⚠️  Profile endpoint returned HTTP #{profile_response[:status]}"
    end
    
    # Update environment variables
    puts "\n🚀 UPDATING ENVIRONMENT VARIABLES:"
    puts "   export CHATWOOT_USER_TOKEN=\"#{best_login[:token]}\""
    if best_login[:user_data]['id']
      puts "   export CHATWOOT_USER_ID=#{best_login[:user_data]['id']}"
    end
    if best_login[:user_data]['email']
      puts "   export CHATWOOT_USER_EMAIL=\"#{best_login[:user_data]['email']}\""
    end
    
    # Actually update the environment file
    env_content = <<~ENV
      
      # ============================================================================
      # VOICELINK ADMIN CREDENTIALS - #{Time.now}
      # ============================================================================
      
      # Working token from #{best_login[:endpoint]}
      export CHATWOOT_USER_TOKEN="#{best_login[:token]}"
      export CHATWOOT_ADMIN_TOKEN="#{best_login[:token]}"
    ENV
    
    if best_login[:user_data]['id']
      env_content += "export CHATWOOT_USER_ID=#{best_login[:user_data]['id']}\n"
      env_content += "export CHATWOOT_ADMIN_USER_ID=#{best_login[:user_data]['id']}\n"
    end
    
    if best_login[:user_data]['email']
      env_content += "export CHATWOOT_USER_EMAIL=\"#{best_login[:user_data]['email']}\"\n"
    end
    
    File.open('azure_database_config.env', 'a') { |f| f.write(env_content) }
    puts "\n✅ Environment variables added to azure_database_config.env"
    
    puts "\n🎯 READY FOR SMS WEBSOCKET TESTS!"
    puts "   1. Source updated environment: source azure_database_config.env"
    puts "   2. Run SMS test: ruby live_websocket_sms_test_auto.rb"
    puts "   3. Run multi-user test: ruby comprehensive_websocket_multi_user_test.rb"
  end
else
  puts "❌ FAILURE: No successful authentications found"
  puts ""
  puts "🔧 TROUBLESHOOTING STEPS:"
  puts "1. Verify credentials are correct for this environment"
  puts "2. Check if user exists in the database"
  puts "3. Verify API server is running and accessible"
  puts "4. Check if authentication endpoints are configured correctly"
  puts ""
  puts "💡 CREDENTIALS TESTED:"
  puts "   Email: #{ADMIN_EMAIL}"
  puts "   Password: #{'*' * ADMIN_PASSWORD.length}"
end

puts "\n📊 Environment Status:"
puts "   API URL: #{BASE_URL}"
puts "   Test completed at: #{Time.now}" 