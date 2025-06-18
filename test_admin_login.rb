#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

puts "🔐 Testing Admin Login Credentials..."

# Configuration
base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
user_email = 'admin@voicelinkai.com'
password = 'KvDDnnFh9sWKYNLw!1A'  # The password we just set

puts "\n🎯 Login Test Details:"
puts "   Email: #{user_email}"
puts "   Password: #{password}"
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
  end
  
  headers.each { |key, value| request[key] = value }
  request.body = body.to_json if body
  
  http.request(request)
end

# Step 1: Test different login endpoints
puts "\n🔍 Testing login endpoints..."

login_endpoints = [
  {
    name: "Standard Login",
    url: "#{base_url}/auth/sign_in",
    body: {
      email: user_email,
      password: password
    }
  },
  {
    name: "API Login",
    url: "#{base_url}/api/v1/auth/sign_in",
    body: {
      email: user_email,
      password: password
    }
  },
  {
    name: "Platform Login",
    url: "#{base_url}/platform/api/v1/users/sign_in",
    body: {
      email: user_email,
      password: password
    }
  },
  {
    name: "Super Admin Login",
    url: "#{base_url}/super_admin/sign_in",
    body: {
      email: user_email,
      password: password
    }
  }
]

headers = {
  'Content-Type' => 'application/json',
  'Accept' => 'application/json'
}

successful_login = false

login_endpoints.each_with_index do |endpoint, index|
  puts "\n#{index + 1}. Testing #{endpoint[:name]}:"
  puts "   URL: #{endpoint[:url]}"
  
  response = make_api_request('POST', endpoint[:url], headers, endpoint[:body])
  
  puts "   Response Code: #{response.code}"
  
  case response.code.to_i
  when 200..299
    puts "   ✅ SUCCESS: Login successful!"
    
    begin
      login_data = JSON.parse(response.body)
      puts "   📊 Response data:"
      
      # Look for common authentication tokens/data
      if login_data['access_token']
        puts "      Access Token: #{login_data['access_token'][0..20]}..."
      end
      
      if login_data['user']
        user = login_data['user']
        puts "      User ID: #{user['id']}"
        puts "      User Name: #{user['name']}"
        puts "      User Email: #{user['email']}"
      end
      
      if login_data['data']
        puts "      Data: #{login_data['data'].keys.join(', ')}"
      end
      
      successful_login = true
      
    rescue JSON::ParserError
      puts "   📄 Raw response: #{response.body[0..200]}"
      successful_login = true
    end
    
  when 400..499
    puts "   ❌ CLIENT ERROR: #{response.code} #{response.message}"
    
    if response.body
      begin
        error_data = JSON.parse(response.body)
        puts "      Error: #{error_data['message'] || error_data['error'] || error_data['errors']}"
      rescue JSON::ParserError
        puts "      Response: #{response.body[0..200]}"
      end
    end
    
  when 500..599
    puts "   💥 SERVER ERROR: #{response.code} #{response.message}"
    puts "      Response: #{response.body[0..100]}" if response.body
    
  else
    puts "   ⚠️  UNEXPECTED: #{response.code} #{response.message}"
  end
end

# Step 2: Verify user still exists and check status
puts "\n🔍 Verifying user account status..."

api_token = 'baea8676c67aba47c08564ce'
verify_headers = {
  'api_access_token' => api_token,
  'Content-Type' => 'application/json',
  'Accept' => 'application/json'
}

agents_url = "#{base_url}/api/v1/accounts/1/agents"
agents_response = make_api_request('GET', agents_url, verify_headers)

if agents_response.code.to_i == 200
  begin
    agents_data = JSON.parse(agents_response.body)
    agents = agents_data['payload'] || agents_data
    
    admin_user = agents.find { |agent| agent['email'] == user_email }
    
    if admin_user
      puts "   ✅ User account found:"
      puts "      ID: #{admin_user['id']}"
      puts "      Name: #{admin_user['name']}"
      puts "      Email: #{admin_user['email']}"
      puts "      Role: #{admin_user['role']}"
      puts "      Status: #{admin_user['availability_status']}"
      puts "      Confirmed: #{admin_user['confirmed_at'] ? 'Yes' : 'No'}"
      puts "      Created: #{admin_user['created_at']}"
      
      # Check if account needs confirmation
      if admin_user['confirmed_at'].nil?
        puts "   ⚠️  WARNING: Account may need email confirmation!"
      end
      
    else
      puts "   ❌ User not found in agents list"
    end
    
  rescue JSON::ParserError => e
    puts "   ❌ Could not parse agents response: #{e.message}"
  end
else
  puts "   ❌ Failed to verify user: #{agents_response.code}"
end

# Step 3: Test web interface accessibility
puts "\n🌐 Testing web interface accessibility..."

web_endpoints = [
  "#{base_url}/app/login",
  "#{base_url}/super_admin",
  "#{base_url}/app"
]

web_endpoints.each do |url|
  puts "\n   Testing: #{url}"
  
  response = make_api_request('GET', url, { 'Accept' => 'text/html' })
  
  case response.code.to_i
  when 200..299
    puts "      ✅ Accessible (#{response.code})"
    
    # Check if it's a login page
    if response.body && response.body.include?('login')
      puts "      📝 Contains login form"
    end
    
  when 300..399
    puts "      🔄 Redirect (#{response.code})"
    if response['Location']
      puts "         → #{response['Location']}"
    end
    
  else
    puts "      ❌ Error (#{response.code})"
  end
end

# Summary and recommendations
puts "\n📝 TROUBLESHOOTING SUMMARY:"

if successful_login
  puts "   ✅ Login credentials are working via API"
  puts "   🎯 Issue may be with web interface or browser"
else
  puts "   ❌ Login credentials failed via API"
  puts "   🎯 Password may need to be reset again"
end

puts "\n💡 RECOMMENDED ACTIONS:"

if !successful_login
  puts "   1. 🔐 Reset password again (may have failed to save)"
  puts "   2. 📧 Check if email confirmation is required"
  puts "   3. 🔍 Verify account is not locked or disabled"
  puts "   4. 🌐 Try different login endpoints"
end

puts "   5. 🧹 Clear browser cache and cookies"
puts "   6. 🔄 Try incognito/private browsing mode"
puts "   7. 🌐 Try different browser"
puts "   8. 📱 Check if 2FA is enabled"

puts "\n🔗 LOGIN DETAILS TO TRY:"
puts "   URL: #{base_url}/app/login"
puts "   Email: #{user_email}"
puts "   Password: #{password}"

puts "\n✨ Login test completed!" 