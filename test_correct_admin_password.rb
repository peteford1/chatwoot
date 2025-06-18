#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'
require 'fileutils'

puts "🔐 Testing Admin Login with Correct Password..."

# Configuration
base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
admin_email = 'admin@voicelinkai.com'
admin_password = 'SuperAdmin123!'

puts "\n🎯 Login Test Details:"
puts "   Email: #{admin_email}"
puts "   Password: #{admin_password}"
puts "   Base URL: #{base_url}"

# Helper function to make API requests
def make_api_request(method, url, headers, body = nil)
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  
  case method.upcase
  when 'GET'
    request = Net::HTTP::Get.new(uri)
  when 'POST'
    request = Net::HTTP::Post.new(uri)
  when 'PATCH'
    request = Net::HTTP::Patch.new(uri)
  when 'PUT'
    request = Net::HTTP::Put.new(uri)
  end
  
  headers.each { |key, value| request[key] = value }
  request.body = body.to_json if body
  
  http.request(request)
end

# Test 1: Standard login endpoint
puts "\n🧪 TEST 1: Standard Login Endpoint"

login_url = "#{base_url}/auth/sign_in"
login_body = {
  email: admin_email,
  password: admin_password
}

login_headers = {
  'Content-Type' => 'application/json',
  'Accept' => 'application/json'
}

login_response = make_api_request('POST', login_url, login_headers, login_body)

puts "   Response Code: #{login_response.code}"
puts "   Response Headers: #{login_response.to_hash.keys.join(', ')}"

case login_response.code.to_i
when 200..299
  puts "   🎉 LOGIN SUCCESS!"
  
  begin
    login_data = JSON.parse(login_response.body)
    puts "   ✅ Login Response Data:"
    
    if login_data['user']
      puts "      User ID: #{login_data['user']['id']}"
      puts "      Name: #{login_data['user']['name']}"
      puts "      Email: #{login_data['user']['email']}"
      puts "      Confirmed: #{login_data['user']['confirmed_at'] ? 'Yes' : 'No'}"
      puts "      Type: #{login_data['user']['type']}"
    end
    
    # Check for authentication headers
    auth_headers = {}
    login_response.to_hash.each do |key, value|
      if ['access-token', 'client', 'uid', 'token-type', 'expiry'].include?(key.downcase)
        auth_headers[key] = value.first
        puts "      #{key}: #{value.first}"
      end
    end
    
    if auth_headers.any?
      puts "   🔑 Authentication headers received - login successful!"
    end
    
  rescue JSON::ParserError => e
    puts "   ⚠️  Response parsing failed: #{e.message}"
    puts "   Raw response: #{login_response.body[0..200]}..."
  end
  
when 401
  puts "   ❌ Login failed: Invalid credentials or unconfirmed account"
  
  begin
    error_data = JSON.parse(login_response.body)
    puts "   Error details: #{error_data}"
  rescue JSON::ParserError
    puts "   Raw error response: #{login_response.body}"
  end
  
when 422
  puts "   ❌ Login failed: Validation error"
  
  begin
    error_data = JSON.parse(login_response.body)
    puts "   Error details: #{error_data}"
  rescue JSON::ParserError
    puts "   Raw error response: #{login_response.body}"
  end
  
else
  puts "   ⚠️  Unexpected response: #{login_response.code}"
  puts "   Response body: #{login_response.body[0..200]}..."
end

# Test 2: Alternative login endpoints
puts "\n🧪 TEST 2: Alternative Login Endpoints"

alternative_endpoints = [
  "#{base_url}/api/v1/auth/sign_in",
  "#{base_url}/users/sign_in",
  "#{base_url}/app/login"
]

alternative_endpoints.each do |endpoint|
  puts "\n   Testing: #{endpoint}"
  
  alt_response = make_api_request('POST', endpoint, login_headers, login_body)
  puts "   Response: #{alt_response.code}"
  
  if alt_response.code.to_i == 200
    puts "   🎉 SUCCESS on alternative endpoint!"
  end
end

# Test 3: Check user status via API
puts "\n🧪 TEST 3: Check User Status via API"

api_token = 'baea8676c67aba47c08564ce'
account_id = 1

api_headers = {
  'api_access_token' => api_token,
  'Content-Type' => 'application/json',
  'Accept' => 'application/json'
}

agents_url = "#{base_url}/api/v1/accounts/#{account_id}/agents"
agents_response = make_api_request('GET', agents_url, api_headers)

if agents_response.code.to_i == 200
  begin
    agents_data = JSON.parse(agents_response.body)
    
    if agents_data.is_a?(Hash) && agents_data['payload']
      all_users = agents_data['payload']
    elsif agents_data.is_a?(Array)
      all_users = agents_data
    end
    
    admin_user = all_users.find { |user| user['email'] == admin_email }
    
    if admin_user
      puts "   👤 Admin User Found:"
      puts "      ID: #{admin_user['id']}"
      puts "      Name: #{admin_user['name']}"
      puts "      Email: #{admin_user['email']}"
      puts "      Confirmed: #{admin_user['confirmed_at'] ? 'Yes ✅' : 'No ❌'}"
      puts "      Confirmed At: #{admin_user['confirmed_at'] || 'Never'}"
      puts "      Type: #{admin_user['type']}"
      puts "      Role: #{admin_user['role']}"
      
      if admin_user['confirmed_at'].nil?
        puts "\n   🔍 DIAGNOSIS: User exists but is NOT confirmed"
        puts "      This explains why login fails with correct password"
      else
        puts "\n   ✅ User is confirmed - password might be incorrect"
      end
    else
      puts "   ❌ Admin user not found in agents list"
    end
    
  rescue JSON::ParserError => e
    puts "   ❌ Could not parse agents response: #{e.message}"
  end
else
  puts "   ❌ Failed to get agents: #{agents_response.code}"
end

# Create backup of test results
backup_info = {
  test_timestamp: Time.now.strftime("%Y-%m-%dT%H:%M:%S%z"),
  admin_email: admin_email,
  password_used: admin_password,
  login_test_result: {
    endpoint: login_url,
    response_code: login_response.code.to_i,
    success: login_response.code.to_i.between?(200, 299)
  },
  user_status_check: agents_response.code.to_i == 200 ? "Success" : "Failed"
}

backup_file = "backup/admin_login_test_#{Time.now.to_i}.json"
FileUtils.mkdir_p("backup")
File.write(backup_file, JSON.pretty_generate(backup_info))

puts "\n✨ Login test completed!"
puts "   📄 Test results saved: #{backup_file}"

if login_response.code.to_i.between?(200, 299)
  puts "\n🎉 SUCCESS: Login working with correct password!"
  puts "   📧 Email: #{admin_email}"
  puts "   🔐 Password: #{admin_password}"
  puts "   🌐 Login URL: #{base_url}/app/login"
else
  puts "\n❌ Login still failing even with correct password"
  puts "   💡 This confirms the email confirmation issue is blocking login"
  puts "   🔧 Configuration fix still required (allow_unconfirmed_access_for)"
end 