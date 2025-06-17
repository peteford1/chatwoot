#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

# Chatwoot Test Environment Configuration
BASE_URL = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
PLATFORM_API_BASE = "#{BASE_URL}/platform/api/v1"
APP_API_BASE = "#{BASE_URL}/api/v1"

puts "=== VoiceLinkAI Test Environment External Seeder ==="
puts "Target: #{BASE_URL}"

def make_request(method, url, headers = {}, body = nil)
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true if uri.scheme == 'https'
  
  request = case method.upcase
  when 'GET'
    Net::HTTP::Get.new(uri)
  when 'POST'
    Net::HTTP::Post.new(uri)
  when 'PUT'
    Net::HTTP::Put.new(uri)
  else
    raise "Unsupported method: #{method}"
  end
  
  headers.each { |key, value| request[key] = value }
  request.body = body.to_json if body
  request['Content-Type'] = 'application/json' if body
  
  response = http.request(request)
  puts "#{method} #{url} -> #{response.code}"
  
  begin
    parsed_body = JSON.parse(response.body) if response.body && !response.body.empty?
    { code: response.code.to_i, body: parsed_body, raw_body: response.body }
  rescue JSON::ParserError
    { code: response.code.to_i, body: nil, raw_body: response.body }
  end
end

begin
  # Step 1: Check if Chatwoot is accessible
  puts "\n1. Checking Chatwoot accessibility..."
  health_check = make_request('GET', BASE_URL)
  
  if health_check[:code] != 200
    puts "❌ Chatwoot test environment not accessible"
    puts "Response: #{health_check[:raw_body]}"
    exit 1
  end
  
  puts "✅ Chatwoot test environment is accessible"
  
  # Step 2: Check installation status
  puts "\n2. Checking installation status..."
  install_check = make_request('GET', "#{BASE_URL}/installation/onboarding")
  
  if install_check[:code] == 200 && install_check[:body]
    installation_status = install_check[:body]
    puts "Installation status: #{installation_status}"
    
    if installation_status['is_account_created'] == true
      puts "⚠️  Account already exists. Checking existing setup..."
      
      # Try to get accounts via Platform API (this will fail without token, but shows structure)
      accounts_check = make_request('GET', "#{PLATFORM_API_BASE}/accounts")
      puts "Accounts check: #{accounts_check[:code]} - #{accounts_check[:raw_body][0..100]}"
      
      puts "\n=== EXISTING SETUP DETECTED ==="
      puts "The test environment appears to already have accounts configured."
      puts "To get tokens for existing setup, you need to:"
      puts "1. Find existing Platform App tokens in the database"
      puts "2. Or create new Platform App via Rails console"
      puts "3. Or reset the test environment"
      
      exit 0
    end
  end
  
  # Step 3: Create initial account via installation API
  puts "\n3. Creating initial account via installation..."
  
  account_data = {
    account: {
      name: 'VoiceLinkAI Test Account',
      locale: 'en'
    },
    user: {
      name: 'VoiceLinkAI Admin',
      email: 'admin@voicelinkai.com',
      password: '123@321Qq',
      password_confirmation: '123@321Qq'
    }
  }
  
  create_response = make_request('POST', "#{BASE_URL}/installation/onboarding", {}, account_data)
  
  if create_response[:code] == 200 && create_response[:body]
    result = create_response[:body]
    puts "✅ Account created successfully!"
    puts "Account ID: #{result['account']['id']}"
    puts "User ID: #{result['user']['id']}"
    puts "User Token: #{result['user']['access_token']['token'][0..20]}..."
    
    user_token = result['user']['access_token']['token']
    account_id = result['account']['id']
    
    # Step 4: Create Platform App via Application API
    puts "\n4. Creating Platform App..."
    
    platform_app_data = {
      platform_app: {
        name: 'VoiceLinkAI Test Platform'
      }
    }
    
    platform_response = make_request(
      'POST', 
      "#{APP_API_BASE}/accounts/#{account_id}/platform_apps",
      { 'api_access_token' => user_token },
      platform_app_data
    )
    
    if platform_response[:code] == 200 && platform_response[:body]
      platform_app = platform_response[:body]
      puts "✅ Platform App created successfully!"
      puts "Platform App ID: #{platform_app['id']}"
      puts "Platform Token: #{platform_app['access_token']['token'][0..20]}..."
      
      platform_token = platform_app['access_token']['token']
      
      # Step 5: Test Platform API
      puts "\n5. Testing Platform API..."
      
      test_response = make_request(
        'GET',
        "#{PLATFORM_API_BASE}/accounts",
        { 'api_access_token' => platform_token }
      )
      
      if test_response[:code] == 200
        puts "✅ Platform API working correctly!"
        accounts = test_response[:body]
        puts "Found #{accounts.length} account(s)"
      else
        puts "⚠️  Platform API test failed: #{test_response[:code]}"
      end
      
      # Final Success Output
      puts "\n=== 🎉 SUCCESS! VoiceLinkAI Test Environment Ready ==="
      puts "Base URL: #{BASE_URL}"
      puts "Platform Token: #{platform_token}"
      puts "Admin Token: #{user_token}"
      puts "Account ID: #{account_id}"
      puts "User ID: #{result['user']['id']}"
      puts ""
      puts "API Endpoints:"
      puts "- Platform API: #{PLATFORM_API_BASE}"
      puts "- Application API: #{APP_API_BASE}"
      puts ""
      puts "Test with:"
      puts "curl -H 'api_access_token: #{platform_token}' #{PLATFORM_API_BASE}/accounts"
      
    else
      puts "❌ Failed to create Platform App"
      puts "Response: #{platform_response[:raw_body]}"
    end
    
  else
    puts "❌ Failed to create initial account"
    puts "Response: #{create_response[:raw_body]}"
  end
  
rescue => e
  puts "❌ ERROR: #{e.message}"
  puts e.backtrace.first(5)
end 