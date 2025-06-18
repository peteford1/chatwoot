#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'
require 'fileutils'

puts "📧 Confirming Admin User Account..."

# Configuration
base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
account_id = 1
api_token = 'baea8676c67aba47c08564ce'
user_email = 'admin@voicelinkai.com'
password = 'Admin123!@#'  # The password we just set

puts "\n🎯 Account Confirmation Details:"
puts "   Email: #{user_email}"
puts "   Password: #{password}"
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

# Step 1: Get current user details to confirm status
puts "\n🔍 Checking current user status..."

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
      puts "      Confirmed At: #{admin_user['confirmed_at'] || 'Not confirmed'}"
      puts "      Created At: #{admin_user['created_at']}"
      
      if admin_user['confirmed_at']
        puts "   ✅ Account is already confirmed!"
      else
        puts "   ⚠️  Account needs confirmation"
      end
    else
      puts "   ❌ Admin user not found"
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

user_id = admin_user['id']

# Step 2: Try different confirmation methods
puts "\n📧 Attempting to confirm user account..."

confirmation_methods = [
  {
    name: "Direct Agent Confirmation",
    method: 'PATCH',
    url: "#{base_url}/api/v1/accounts/#{account_id}/agents/#{user_id}",
    body: { 
      confirmed_at: Time.now.strftime("%Y-%m-%dT%H:%M:%S.%LZ"),
      name: admin_user['name'],
      email: admin_user['email']
    }
  },
  {
    name: "Agent Confirmation (simple)",
    method: 'PATCH',
    url: "#{base_url}/api/v1/accounts/#{account_id}/agents/#{user_id}",
    body: { confirmed_at: Time.now.strftime("%Y-%m-%dT%H:%M:%S.%LZ") }
  },
  {
    name: "User Confirmation",
    method: 'PUT',
    url: "#{base_url}/api/v1/accounts/#{account_id}/users/#{user_id}",
    body: { confirmed_at: Time.now.strftime("%Y-%m-%dT%H:%M:%S.%LZ") }
  }
]

confirmation_success = false
successful_method = nil

confirmation_methods.each_with_index do |method_info, index|
  puts "\n#{index + 1}. Trying #{method_info[:name]}:"
  puts "   URL: #{method_info[:url]}"
  
  response = make_api_request(method_info[:method], method_info[:url], headers, method_info[:body])
  
  puts "   Response Code: #{response.code}"
  
  case response.code.to_i
  when 200..299
    puts "   ✅ SUCCESS: User confirmation successful"
    
    begin
      response_data = JSON.parse(response.body)
      puts "   📊 Updated user data:"
      puts "      ID: #{response_data['id']}"
      puts "      Email: #{response_data['email']}"
      puts "      Name: #{response_data['name']}"
      puts "      Confirmed At: #{response_data['confirmed_at']}"
      
      confirmation_success = true
      successful_method = method_info[:name]
      break
      
    rescue JSON::ParserError
      puts "   📄 Raw response: #{response.body[0..100]}"
      confirmation_success = true
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

# Step 3: If confirmation failed, try manual confirmation via Rails console approach
if !confirmation_success
  puts "\n🔧 Trying alternative confirmation method..."
  
  # Try to send confirmation email
  confirmation_email_url = "#{base_url}/api/v1/accounts/#{account_id}/agents/#{user_id}/resend_confirmation"
  email_response = make_api_request('POST', confirmation_email_url, headers)
  
  puts "   Resend confirmation email: #{email_response.code}"
  
  if email_response.code.to_i == 200
    puts "   ✅ Confirmation email sent"
    puts "   📧 Check email for confirmation link"
  else
    puts "   ❌ Failed to send confirmation email"
  end
end

# Step 4: Test login after confirmation
puts "\n🧪 Testing login after confirmation..."

login_url = "#{base_url}/auth/sign_in"
login_body = {
  email: user_email,
  password: password
}

login_headers = {
  'Content-Type' => 'application/json',
  'Accept' => 'application/json'
}

login_response = make_api_request('POST', login_url, login_headers, login_body)

puts "   Login Test Response: #{login_response.code}"

case login_response.code.to_i
when 200..299
  puts "   ✅ SUCCESS: Login works after confirmation!"
  
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
  puts "      Account may still need manual confirmation"
  
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

# Step 5: Final verification - check user status again
puts "\n🔍 Final user status check..."

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
    
    final_admin_user = final_agents.find { |agent| agent['email'] == user_email }
    
    if final_admin_user
      puts "   📊 Final user status:"
      puts "      ID: #{final_admin_user['id']}"
      puts "      Name: #{final_admin_user['name']}"
      puts "      Email: #{final_admin_user['email']}"
      puts "      Role: #{final_admin_user['role']}"
      puts "      Confirmed: #{final_admin_user['confirmed_at'] ? 'Yes' : 'No'}"
      puts "      Confirmed At: #{final_admin_user['confirmed_at'] || 'Not confirmed'}"
    end
    
  rescue JSON::ParserError => e
    puts "   ❌ Could not parse final response: #{e.message}"
  end
end

# Step 6: Create backup and summary
backup_info = {
  confirmation_timestamp: Time.now.strftime("%Y-%m-%dT%H:%M:%S%z"),
  user_email: user_email,
  user_id: user_id,
  password: password,
  confirmation_success: confirmation_success,
  successful_method: successful_method,
  login_test_result: login_response.code.to_i,
  original_user_data: admin_user
}

backup_file = "backup/user_confirmation_#{user_id}_#{Time.now.to_i}.json"
FileUtils.mkdir_p("backup")
File.write(backup_file, JSON.pretty_generate(backup_info))

puts "\n✨ User confirmation process completed!"
puts "   📄 Backup: #{backup_file}"

if confirmation_success && login_response.code.to_i == 200
  puts "\n🎉 SUCCESS: Account confirmed and login working!"
  puts "   📧 Email: #{user_email}"
  puts "   🔐 Password: #{password}"
  puts "   🔗 Login URL: #{base_url}/app/login"
  puts "   ✅ Method used: #{successful_method}"
  
elsif confirmation_success
  puts "\n⚠️  Account was confirmed but login still fails"
  puts "   📧 Email: #{user_email}"
  puts "   🔐 Password: #{password}"
  puts "   🔗 Login URL: #{base_url}/app/login"
  puts "   ⚠️  Try waiting a few minutes for changes to propagate"
  
elsif login_response.code.to_i == 200
  puts "\n🎉 SUCCESS: Login working (confirmation may have been automatic)!"
  puts "   📧 Email: #{user_email}"
  puts "   🔐 Password: #{password}"
  puts "   🔗 Login URL: #{base_url}/app/login"
  
else
  puts "\n❌ Account confirmation and login both failed"
  puts "   📋 Next steps:"
  puts "   1. Check email for confirmation link"
  puts "   2. Try manual confirmation via web interface"
  puts "   3. Contact system administrator"
  puts "   4. Check server logs for authentication issues"
end 