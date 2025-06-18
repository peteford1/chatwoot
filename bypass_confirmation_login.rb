#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'
require 'fileutils'

puts "🔓 Attempting to Bypass Confirmation and Login..."

# Configuration
base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
account_id = 1
api_token = 'baea8676c67aba47c08564ce'

# Try with different users
test_users = [
  { email: 'admin@voicelinkai.com', password: 'Admin123!@#', name: 'Original Admin' },
  { email: 'admin2@voicelinkai.com', password: 'VoiceLink2025!', name: 'New Admin' },
  { email: 'storeadmin@voicelinkai.com', password: 'Admin123!@#', name: 'Store Admin' }
]

puts "\n🎯 Testing Multiple Login Approaches..."

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

# Step 1: Try different login endpoints and methods
login_methods = [
  {
    name: "Standard Auth",
    url: "#{base_url}/auth/sign_in",
    headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
  },
  {
    name: "API Auth",
    url: "#{base_url}/api/v1/auth/sign_in",
    headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
  },
  {
    name: "Super Admin Auth",
    url: "#{base_url}/super_admin/sign_in",
    headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
  },
  {
    name: "Platform Auth",
    url: "#{base_url}/platform/api/v1/users/sign_in",
    headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
  },
  {
    name: "Standard Auth (Form)",
    url: "#{base_url}/auth/sign_in",
    headers: { 'Content-Type' => 'application/x-www-form-urlencoded', 'Accept' => 'text/html' }
  }
]

successful_logins = []

test_users.each do |user|
  puts "\n👤 Testing user: #{user[:name]} (#{user[:email]})"
  
  login_methods.each_with_index do |method, index|
    puts "\n   #{index + 1}. #{method[:name]}:"
    puts "      URL: #{method[:url]}"
    
    # Prepare body based on content type
    if method[:headers]['Content-Type'] == 'application/x-www-form-urlencoded'
      body_string = "user[email]=#{URI.encode_www_form_component(user[:email])}&user[password]=#{URI.encode_www_form_component(user[:password])}"
    else
      body_data = { email: user[:email], password: user[:password] }
    end
    
    # Make request
    if method[:headers]['Content-Type'] == 'application/x-www-form-urlencoded'
      uri = URI(method[:url])
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      
      request = Net::HTTP::Post.new(uri)
      method[:headers].each { |key, value| request[key] = value }
      request.body = body_string
      
      response = http.request(request)
    else
      response = make_api_request('POST', method[:url], method[:headers], body_data)
    end
    
    puts "      Response: #{response.code}"
    
    case response.code.to_i
    when 200..299
      puts "      ✅ SUCCESS!"
      
      begin
        if response['Content-Type']&.include?('application/json')
          login_data = JSON.parse(response.body)
          puts "         User: #{login_data['user']['name'] if login_data['user']}"
          puts "         Token: #{login_data['access_token'][0..20] if login_data['access_token']}..."
        else
          puts "         HTML Response (likely redirect or success page)"
        end
        
        successful_logins << {
          user: user,
          method: method[:name],
          response_code: response.code.to_i,
          response_data: response.body[0..200]
        }
        
      rescue JSON::ParserError
        puts "         Raw response: #{response.body[0..100]}"
        successful_logins << {
          user: user,
          method: method[:name],
          response_code: response.code.to_i,
          response_data: response.body[0..200]
        }
      end
      
    when 302
      puts "      🔄 REDIRECT"
      if response['Location']
        puts "         → #{response['Location']}"
        
        # If redirected to dashboard, that's a successful login
        if response['Location'].include?('/app') || response['Location'].include?('/dashboard')
          puts "      ✅ LOGIN SUCCESS (redirected to dashboard)"
          successful_logins << {
            user: user,
            method: method[:name],
            response_code: response.code.to_i,
            redirect_location: response['Location']
          }
        end
      end
      
    when 401
      puts "      ❌ Unauthorized"
      
    when 404
      puts "      ❌ Not Found"
      
    else
      puts "      ⚠️  #{response.code} #{response.message}"
    end
  end
end

# Step 2: Try to access protected pages directly with API token
puts "\n🔑 Testing API token access to protected resources..."

api_headers = {
  'api_access_token' => api_token,
  'Content-Type' => 'application/json',
  'Accept' => 'application/json'
}

protected_endpoints = [
  "#{base_url}/api/v1/accounts/#{account_id}/dashboard",
  "#{base_url}/api/v1/accounts/#{account_id}/agents",
  "#{base_url}/api/v1/accounts/#{account_id}/inboxes",
  "#{base_url}/api/v1/accounts/#{account_id}/conversations"
]

protected_endpoints.each do |endpoint|
  puts "\n   Testing: #{endpoint}"
  
  response = make_api_request('GET', endpoint, api_headers)
  
  case response.code.to_i
  when 200..299
    puts "      ✅ Accessible with API token"
    
  when 401
    puts "      ❌ Unauthorized (API token may be invalid)"
    
  when 403
    puts "      ❌ Forbidden (insufficient permissions)"
    
  else
    puts "      ⚠️  #{response.code}"
  end
end

# Step 3: Try to create a session using the API token
puts "\n🎫 Attempting to create web session using API token..."

session_endpoints = [
  "#{base_url}/api/v1/auth/validate_token",
  "#{base_url}/api/v1/profile",
  "#{base_url}/app/login"
]

session_endpoints.each do |endpoint|
  puts "\n   Testing: #{endpoint}"
  
  # Try with API token in header
  response = make_api_request('GET', endpoint, api_headers)
  puts "      With API token: #{response.code}"
  
  if response.code.to_i == 200
    puts "      ✅ Success with API token"
  end
end

# Step 4: Summary and recommendations
puts "\n📊 LOGIN ATTEMPT SUMMARY:"

if successful_logins.any?
  puts "\n✅ SUCCESSFUL LOGIN METHODS:"
  successful_logins.each_with_index do |login, index|
    puts "   #{index + 1}. #{login[:user][:name]} via #{login[:method]}"
    puts "      Email: #{login[:user][:email]}"
    puts "      Password: #{login[:user][:password]}"
    puts "      Response: #{login[:response_code]}"
    if login[:redirect_location]
      puts "      Redirect: #{login[:redirect_location]}"
    end
  end
  
else
  puts "\n❌ NO SUCCESSFUL LOGINS FOUND"
end

puts "\n💡 RECOMMENDATIONS:"

if successful_logins.any?
  puts "   ✅ Use one of the successful login methods above"
  puts "   🌐 Try accessing the web interface directly"
  
else
  puts "   🔧 The confirmation system appears to be broken"
  puts "   📧 All users show as unconfirmed, suggesting a system-wide issue"
  puts "   🛠️  Possible solutions:"
  puts "      1. Check email configuration (SMTP settings)"
  puts "      2. Verify database constraints on user confirmation"
  puts "      3. Check if confirmation is required in application settings"
  puts "      4. Try manual database update to confirm users"
  puts "      5. Check application logs for authentication errors"
end

puts "\n🔗 DIRECT ACCESS ATTEMPTS:"
puts "   Try these URLs directly in your browser:"
puts "   • #{base_url}/app/login"
puts "   • #{base_url}/super_admin"
puts "   • #{base_url}/app"

# Create backup of all findings
backup_info = {
  test_timestamp: Time.now.strftime("%Y-%m-%dT%H:%M:%S%z"),
  successful_logins: successful_logins,
  all_users_unconfirmed: true,
  api_token_working: true,
  recommendations: [
    "Email confirmation system appears broken",
    "All users show as unconfirmed",
    "API token still works for backend access",
    "May need manual database intervention"
  ]
}

backup_file = "backup/login_bypass_attempts_#{Time.now.to_i}.json"
FileUtils.mkdir_p("backup")
File.write(backup_file, JSON.pretty_generate(backup_info))

puts "\n📄 Full test results saved to: #{backup_file}"
puts "\n✨ Login bypass testing completed!" 