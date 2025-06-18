#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

# Configuration
API_BASE = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
ACCOUNT_ID = 1

def log_step(step, message)
  timestamp = Time.now.strftime("%H:%M:%S")
  puts "\n[#{timestamp}] #{step} #{message}"
end

def log_result(status, message)
  icon = status == :success ? "✅" : (status == :error ? "❌" : "⚠️")
  puts "   #{icon} #{message}"
end

def make_api_request(method, endpoint, headers = {}, body = nil)
  uri = URI("#{API_BASE}#{endpoint}")
  
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.open_timeout = 10
  http.read_timeout = 30
  
  case method.upcase
  when 'GET'
    request = Net::HTTP::Get.new(uri)
  when 'POST'
    request = Net::HTTP::Post.new(uri)
    request.body = body if body
    request['Content-Type'] = 'application/json'
  when 'DELETE'
    request = Net::HTTP::Delete.new(uri)
  end
  
  headers.each { |key, value| request[key] = value }
  
  response = http.request(request)
  return response
rescue => e
  log_result(:error, "API request failed: #{e.message}")
  return nil
end

def login_admin_user
  log_step("🔑 STEP 1:", "Logging in existing admin user")
  
  # Try common admin credentials
  login_data = {
    email: "admin@voicelinkai.com",
    password: "SuperAdmin123!"
  }
  
  response = make_api_request(
    'POST',
    "/auth/sign_in",
    {},
    login_data.to_json
  )
  
  if response && response.code == '200'
    # Extract auth headers
    auth_headers = {
      'access-token' => response['access-token'],
      'client' => response['client'],
      'uid' => response['uid']
    }
    
    log_result(:success, "Admin login successful")
    log_result(:success, "Access token: #{auth_headers['access-token'][0..20]}...")
    return auth_headers
  else
    log_result(:error, "Admin login failed: #{response&.code} - #{response&.body}")
    return nil
  end
end

def create_new_api_token(auth_headers)
  log_step("🔧 STEP 2:", "Creating new API access token")
  
  token_data = {
    name: "WebSocket Test Token - #{Time.now.to_i}"
  }
  
  response = make_api_request(
    'POST',
    "/api/v1/profile/access_tokens",
    auth_headers,
    token_data.to_json
  )
  
  if response && response.code.to_i < 400
    token_info = JSON.parse(response.body)
    new_token = token_info['access_token']
    log_result(:success, "Created new API token: #{new_token[0..20]}...")
    return new_token
  else
    log_result(:error, "Failed to create API token: #{response&.code} - #{response&.body}")
    return nil
  end
end

def test_new_token(token)
  log_step("✅ STEP 3:", "Testing new API token")
  
  response = make_api_request(
    'GET',
    "/api/v1/accounts/#{ACCOUNT_ID}/agents",
    { 'api_access_token' => token }
  )
  
  if response && response.code == '200'
    data = JSON.parse(response.body)
    agents = data['payload'] || data
    log_result(:success, "Token works! Found #{agents.length} agents")
    return true
  else
    log_result(:error, "Token test failed: #{response&.code} - #{response&.body}")
    return false
  end
end

def refresh_admin_token
  puts "🔄 REFRESHING ADMIN API TOKEN"
  puts "=" * 50
  
  begin
    # Step 1: Login admin user
    auth_headers = login_admin_user
    return nil unless auth_headers
    
    # Step 2: Create new API token
    new_token = create_new_api_token(auth_headers)
    return nil unless new_token
    
    # Step 3: Test new token
    if test_new_token(new_token)
      log_result(:success, "🎉 New admin token ready!")
      puts "\n" + "=" * 50
      puts "NEW API TOKEN: #{new_token}"
      puts "=" * 50
      return new_token
    else
      return nil
    end
    
  rescue => e
    log_result(:error, "Token refresh failed: #{e.message}")
    return nil
  end
end

# Run the refresh
if __FILE__ == $0
  new_token = refresh_admin_token
  
  if new_token
    puts "\n✅ SUCCESS: Admin token refreshed successfully!"
    puts "Use this token in your tests: #{new_token}"
    exit(0)
  else
    puts "\n❌ FAILED: Could not refresh admin token"
    exit(1)
  end
end 