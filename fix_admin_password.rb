#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'
require 'fileutils'
require 'securerandom'

puts "🔧 Fixing Admin Password Issue..."

# Configuration
base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
account_id = 1
api_token = 'baea8676c67aba47c08564ce'
user_email = 'admin@voicelinkai.com'

# Generate a new, simpler password for testing
new_password = "Admin123!@#"  # Simpler password to test

puts "\n🎯 Password Fix Details:"
puts "   Email: #{user_email}"
puts "   New Password: #{new_password}"
puts "   Account ID: #{account_id}"

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

headers = {
  'api_access_token' => api_token,
  'Content-Type' => 'application/json',
  'Accept' => 'application/json'
}

# Step 1: Get current user details
puts "\n🔍 Getting current user details..."

agents_url = "#{base_url}/api/v1/accounts/#{account_id}/agents"
agents_response = make_api_request('GET', agents_url, headers)

admin_user = nil

if agents_response.code.to_i == 200
  begin
    agents_data = JSON.parse(agents_response.body)
    
    # Handle the response format properly
    if agents_data.is_a?(Hash) && agents_data['payload']
      agents = agents_data['payload']
    elsif agents_data.is_a?(Array)
      agents = agents_data
    else
      agents = []
    end
    
    admin_user = agents.find { |agent| agent['email'] == user_email }
    
    if admin_user
      puts "   ✅ Found admin user:"
      puts "      ID: #{admin_user['id']}"
      puts "      Name: #{admin_user['name']}"
      puts "      Email: #{admin_user['email']}"
      puts "      Role: #{admin_user['role']}"
      puts "      Confirmed: #{admin_user['confirmed_at'] ? 'Yes' : 'No'}"
    else
      puts "   ❌ Admin user not found"
      puts "   📋 Available users:"
      agents.each do |agent|
        puts "      - #{agent['email']} (ID: #{agent['id']})"
      end
      exit 1
    end
    
  rescue JSON::ParserError => e
    puts "   ❌ Could not parse response: #{e.message}"
    exit 1
  end
else
  puts "   ❌ Failed to get agents: #{agents_response.code}"
  exit 1
end

# Step 2: Try multiple password reset approaches
puts "\n🔐 Attempting password reset with multiple methods..."

user_id = admin_user['id']

reset_methods = [
  {
    name: "Agent Update (with confirmation)",
    method: 'PATCH',
    url: "#{base_url}/api/v1/accounts/#{account_id}/agents/#{user_id}",
    body: { 
      password: new_password, 
      password_confirmation: new_password,
      name: admin_user['name'],
      email: admin_user['email']
    }
  },
  {
    name: "Agent Update (password only)",
    method: 'PATCH',
    url: "#{base_url}/api/v1/accounts/#{account_id}/agents/#{user_id}",
    body: { password: new_password }
  },
  {
    name: "User Update",
    method: 'PUT',
    url: "#{base_url}/api/v1/accounts/#{account_id}/users/#{user_id}",
    body: { 
      password: new_password,
      password_confirmation: new_password
    }
  }
]

success = false
successful_method = nil

reset_methods.each_with_index do |method_info, index|
  puts "\n#{index + 1}. Trying #{method_info[:name]}:"
  puts "   URL: #{method_info[:url]}"
  
  response = make_api_request(method_info[:method], method_info[:url], headers, method_info[:body])
  
  puts "   Response Code: #{response.code}"
  
  case response.code.to_i
  when 200..299
    puts "   ✅ SUCCESS: Password update successful"
    
    begin
      response_data = JSON.parse(response.body)
      puts "   📊 Updated user data:"
      puts "      ID: #{response_data['id']}"
      puts "      Email: #{response_data['email']}"
      puts "      Name: #{response_data['name']}"
      
      success = true
      successful_method = method_info[:name]
      break
      
    rescue JSON::ParserError
      puts "   📄 Raw response: #{response.body[0..100]}"
      success = true
      successful_method = method_info[:name]
      break
    end
    
  when 400..499
    puts "   ❌ Client Error: #{response.code}"
    if response.body
      begin
        error_data = JSON.parse(response.body)
        puts "      Error: #{error_data['message'] || error_data['error'] || error_data['errors']}"
      rescue JSON::ParserError
        puts "      Response: #{response.body[0..200]}"
      end
    end
    
  when 500..599
    puts "   💥 Server Error: #{response.code}"
    puts "      Response: #{response.body[0..100]}" if response.body
    
  else
    puts "   ⚠️  Unexpected: #{response.code}"
  end
end

if !success
  puts "\n❌ All password reset methods failed!"
  exit 1
end

# Step 3: Test the new password immediately
puts "\n🧪 Testing new password..."

login_url = "#{base_url}/auth/sign_in"
login_body = {
  email: user_email,
  password: new_password
}

login_headers = {
  'Content-Type' => 'application/json',
  'Accept' => 'application/json'
}

login_response = make_api_request('POST', login_url, login_headers, login_body)

puts "   Login Test Response: #{login_response.code}"

case login_response.code.to_i
when 200..299
  puts "   ✅ SUCCESS: Login works with new password!"
  
  begin
    login_data = JSON.parse(login_response.body)
    if login_data['user']
      puts "      Logged in as: #{login_data['user']['name']} (#{login_data['user']['email']})"
    end
  rescue JSON::ParserError
    puts "      Login successful (raw response)"
  end
  
when 401
  puts "   ❌ FAILED: Still getting invalid credentials"
  puts "      The password may not have been saved properly"
  
  if login_response.body
    begin
      error_data = JSON.parse(login_response.body)
      puts "      Error: #{error_data['message'] || error_data['error']}"
    rescue JSON::ParserError
      puts "      Response: #{login_response.body[0..100]}"
    end
  end
  
else
  puts "   ⚠️  Unexpected login response: #{login_response.code}"
end

# Step 4: Create backup and summary
backup_info = {
  fix_timestamp: Time.now.strftime("%Y-%m-%dT%H:%M:%S%z"),
  user_email: user_email,
  user_id: user_id,
  new_password: new_password,
  successful_method: successful_method,
  login_test_result: login_response.code.to_i,
  original_user_data: admin_user
}

backup_file = "backup/password_fix_#{user_id}_#{Time.now.to_i}.json"
FileUtils.mkdir_p("backup")
File.write(backup_file, JSON.pretty_generate(backup_info))

puts "\n✨ Password fix completed!"
puts "   📄 Backup: #{backup_file}"

if success && login_response.code.to_i == 200
  puts "\n🎉 SUCCESS: Password fixed and login working!"
  puts "   📧 Email: #{user_email}"
  puts "   🔐 Password: #{new_password}"
  puts "   🔗 Login URL: #{base_url}/app/login"
  puts "   ✅ Method used: #{successful_method}"
  
elsif success
  puts "\n⚠️  Password was updated but login still fails"
  puts "   📧 Email: #{user_email}"
  puts "   🔐 Password: #{new_password}"
  puts "   🔗 Login URL: #{base_url}/app/login"
  puts "   ⚠️  Try waiting a few minutes for changes to propagate"
  
else
  puts "\n❌ Password fix failed"
  puts "   📋 Next steps:"
  puts "   1. Check if user account is locked"
  puts "   2. Verify email confirmation status"
  puts "   3. Try manual password reset via web interface"
  puts "   4. Contact system administrator"
end 