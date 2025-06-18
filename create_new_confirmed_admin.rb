#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'
require 'fileutils'

puts "👤 Creating New Confirmed Admin User..."

# Configuration
base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
account_id = 1
api_token = 'baea8676c67aba47c08564ce'

# New admin user details
new_admin_email = 'admin2@voicelinkai.com'
new_admin_password = 'VoiceLink2025!'
new_admin_name = 'VoiceLink Admin'

puts "\n🎯 New Admin User Details:"
puts "   Email: #{new_admin_email}"
puts "   Password: #{new_admin_password}"
puts "   Name: #{new_admin_name}"
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
  when 'DELETE'
    request = Net::HTTP::Delete.new(uri)
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

# Step 1: Check if the new email already exists
puts "\n🔍 Checking if new admin email already exists..."

agents_url = "#{base_url}/api/v1/accounts/#{account_id}/agents"
agents_response = make_api_request('GET', agents_url, headers)

existing_user = nil

if agents_response.code.to_i == 200
  begin
    agents_data = JSON.parse(agents_response.body)
    
    if agents_data.is_a?(Hash) && agents_data['payload']
      agents = agents_data['payload']
    elsif agents_data.is_a?(Array)
      agents = agents_data
    else
      agents = []
    end
    
    existing_user = agents.find { |agent| agent['email'] == new_admin_email }
    
    if existing_user
      puts "   ⚠️  User with email #{new_admin_email} already exists (ID: #{existing_user['id']})"
      puts "   🗑️  Deleting existing user first..."
      
      delete_url = "#{base_url}/api/v1/accounts/#{account_id}/agents/#{existing_user['id']}"
      delete_response = make_api_request('DELETE', delete_url, headers)
      
      if delete_response.code.to_i == 200
        puts "      ✅ Existing user deleted successfully"
      else
        puts "      ❌ Failed to delete existing user: #{delete_response.code}"
      end
    else
      puts "   ✅ Email is available"
    end
    
  rescue JSON::ParserError => e
    puts "   ❌ Could not parse agents response: #{e.message}"
  end
else
  puts "   ❌ Failed to get agents: #{agents_response.code}"
end

# Step 2: Create new admin user
puts "\n👤 Creating new admin user..."

create_user_body = {
  name: new_admin_name,
  email: new_admin_email,
  password: new_admin_password,
  password_confirmation: new_admin_password,
  role: 'administrator',
  confirmed_at: Time.now.strftime("%Y-%m-%dT%H:%M:%S.%LZ")  # Pre-confirm the user
}

create_url = "#{base_url}/api/v1/accounts/#{account_id}/agents"
create_response = make_api_request('POST', create_url, headers, create_user_body)

puts "   Create User Response: #{create_response.code}"

new_user = nil

case create_response.code.to_i
when 200..299
  puts "   ✅ SUCCESS: New admin user created!"
  
  begin
    new_user = JSON.parse(create_response.body)
    puts "   📊 New user details:"
    puts "      ID: #{new_user['id']}"
    puts "      Name: #{new_user['name']}"
    puts "      Email: #{new_user['email']}"
    puts "      Role: #{new_user['role']}"
    puts "      Confirmed: #{new_user['confirmed_at'] ? 'Yes' : 'No'}"
    puts "      Confirmed At: #{new_user['confirmed_at'] || 'Not confirmed'}"
    
  rescue JSON::ParserError
    puts "   📄 Raw response: #{create_response.body[0..200]}"
  end
  
when 400..499
  puts "   ❌ Client Error: #{create_response.code}"
  if create_response.body
    begin
      error_data = JSON.parse(create_response.body)
      puts "      Error: #{error_data['message'] || error_data['error'] || error_data['errors']}"
    rescue JSON::ParserError
      puts "      Response: #{create_response.body[0..200]}"
    end
  end
  
when 500..599
  puts "   💥 Server Error: #{create_response.code}"
  puts "      Response: #{create_response.body[0..100]}" if create_response.body
  
else
  puts "   ⚠️  Unexpected: #{create_response.code}"
end

# Step 3: If user was created but not confirmed, try to confirm it
if new_user && new_user['id'] && !new_user['confirmed_at']
  puts "\n📧 User created but not confirmed, attempting confirmation..."
  
  user_id = new_user['id']
  
  confirm_body = {
    confirmed_at: Time.now.strftime("%Y-%m-%dT%H:%M:%S.%LZ"),
    name: new_user['name'],
    email: new_user['email']
  }
  
  confirm_url = "#{base_url}/api/v1/accounts/#{account_id}/agents/#{user_id}"
  confirm_response = make_api_request('PATCH', confirm_url, headers, confirm_body)
  
  puts "   Confirmation Response: #{confirm_response.code}"
  
  if confirm_response.code.to_i == 200
    puts "   ✅ User confirmed successfully"
    
    begin
      confirmed_user = JSON.parse(confirm_response.body)
      new_user = confirmed_user  # Update our user data
    rescue JSON::ParserError
      # Keep existing user data
    end
  else
    puts "   ❌ Failed to confirm user"
  end
end

# Step 4: Test login with new user
if new_user && new_user['id']
  puts "\n🧪 Testing login with new admin user..."
  
  login_url = "#{base_url}/auth/sign_in"
  login_body = {
    email: new_admin_email,
    password: new_admin_password
  }
  
  login_headers = {
    'Content-Type' => 'application/json',
    'Accept' => 'application/json'
  }
  
  login_response = make_api_request('POST', login_url, login_headers, login_body)
  
  puts "   Login Test Response: #{login_response.code}"
  
  case login_response.code.to_i
  when 200..299
    puts "   ✅ SUCCESS: Login works with new admin user!"
    
    begin
      login_data = JSON.parse(login_response.body)
      if login_data['user']
        puts "      Logged in as: #{login_data['user']['name']} (#{login_data['user']['email']})"
      end
    rescue JSON::ParserError
      puts "      Login successful (raw response)"
    end
    
  when 401
    puts "   ❌ FAILED: Invalid credentials for new user"
    
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
  
  # Step 5: Final verification - get updated user details
  puts "\n🔍 Final verification of new user..."
  
  final_agents_response = make_api_request('GET', agents_url, headers)
  
  if final_agents_response.code.to_i == 200
    begin
      final_agents_data = JSON.parse(final_agents_response.body)
      
      if final_agents_data.is_a?(Hash) && final_agents_data['payload']
        final_agents = final_agents_data['payload']
      elsif final_agents_data.is_a?(Array)
        final_agents = final_agents_data
      else
        final_agents = []
      end
      
      final_new_user = final_agents.find { |agent| agent['email'] == new_admin_email }
      
      if final_new_user
        puts "   📊 Final new user status:"
        puts "      ID: #{final_new_user['id']}"
        puts "      Name: #{final_new_user['name']}"
        puts "      Email: #{final_new_user['email']}"
        puts "      Role: #{final_new_user['role']}"
        puts "      Confirmed: #{final_new_user['confirmed_at'] ? 'Yes' : 'No'}"
        puts "      Confirmed At: #{final_new_user['confirmed_at'] || 'Not confirmed'}"
        puts "      Created At: #{final_new_user['created_at']}"
      else
        puts "   ❌ New user not found in final check"
      end
      
    rescue JSON::ParserError => e
      puts "   ❌ Could not parse final response: #{e.message}"
    end
  end
  
  # Step 6: Create backup
  backup_info = {
    creation_timestamp: Time.now.strftime("%Y-%m-%dT%H:%M:%S%z"),
    new_user_email: new_admin_email,
    new_user_password: new_admin_password,
    new_user_name: new_admin_name,
    user_created: new_user ? true : false,
    user_id: new_user ? new_user['id'] : nil,
    login_test_result: login_response ? login_response.code.to_i : nil,
    user_data: new_user
  }
  
  backup_file = "backup/new_admin_creation_#{Time.now.to_i}.json"
  FileUtils.mkdir_p("backup")
  File.write(backup_file, JSON.pretty_generate(backup_info))
  
  puts "\n✨ New admin user creation completed!"
  puts "   📄 Backup: #{backup_file}"
  
  if login_response && login_response.code.to_i == 200
    puts "\n🎉 SUCCESS: New admin user created and login working!"
    puts "   📧 Email: #{new_admin_email}"
    puts "   🔐 Password: #{new_admin_password}"
    puts "   🔗 Login URL: #{base_url}/app/login"
    puts "   👤 User ID: #{new_user['id']}"
    
  else
    puts "\n⚠️  New admin user created but login may still have issues"
    puts "   📧 Email: #{new_admin_email}"
    puts "   🔐 Password: #{new_admin_password}"
    puts "   🔗 Login URL: #{base_url}/app/login"
    puts "   ⚠️  Try waiting a few minutes or check confirmation status"
  end
  
else
  puts "\n❌ Failed to create new admin user"
  puts "   📋 Next steps:"
  puts "   1. Check API permissions"
  puts "   2. Verify account limits"
  puts "   3. Check server logs"
  puts "   4. Try manual user creation via web interface"
end

# Step 7: Show all current users for reference
puts "\n📋 Current users in the system:"

if agents_response.code.to_i == 200
  begin
    agents_data = JSON.parse(agents_response.body)
    
    if agents_data.is_a?(Hash) && agents_data['payload']
      agents = agents_data['payload']
    elsif agents_data.is_a?(Array)
      agents = agents_data
    else
      agents = []
    end
    
    agents.each do |agent|
      status = agent['confirmed_at'] ? '✅' : '❌'
      puts "   #{status} #{agent['email']} (ID: #{agent['id']}, Role: #{agent['role']})"
    end
    
  rescue JSON::ParserError
    puts "   ❌ Could not parse users list"
  end
end 