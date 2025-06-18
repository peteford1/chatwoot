#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'
require 'fileutils'
require 'securerandom'

puts "🔐 Creating/Resetting Admin User: admin@voicelinkai.com..."

# Configuration
base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
account_id = 1
api_token = 'baea8676c67aba47c08564ce'
user_email = 'admin@voicelinkai.com'

# Generate a secure new password
new_password = SecureRandom.alphanumeric(16) + "!1A"

puts "\n🎯 Admin User Details:"
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

# Step 1: Try to find existing users via different endpoints
puts "\n🔍 Searching for existing users..."

user_endpoints = [
  "#{base_url}/api/v1/accounts/#{account_id}/agents",
  "#{base_url}/api/v1/accounts/#{account_id}/team_members", 
  "#{base_url}/super_admin/users",
  "#{base_url}/api/v1/profile"
]

existing_users = []
user_found = false
target_user = nil

user_endpoints.each_with_index do |endpoint, index|
  puts "\n   Trying endpoint #{index + 1}: #{endpoint.split('/').last(2).join('/')}"
  
  response = make_api_request('GET', endpoint, headers)
  
  case response.code.to_i
  when 200..299
    begin
      data = JSON.parse(response.body)
      
      # Handle different response formats
      users = nil
      if data.is_a?(Array)
        users = data
      elsif data.is_a?(Hash)
        users = data['payload'] || data['data'] || data['agents'] || data['users'] || [data]
      end
      
      if users && users.any?
        puts "      ✅ Found #{users.length} user(s)"
        
        users.each do |user|
          if user.is_a?(Hash) && user['email']
            existing_users << user
            puts "         - #{user['email']} (ID: #{user['id']}, Name: #{user['name']})"
            
            if user['email'] == user_email
              target_user = user
              user_found = true
              puts "         🎯 Found target user!"
            end
          end
        end
      else
        puts "      ❌ No users found"
      end
      
    rescue JSON::ParserError => e
      puts "      ⚠️  Could not parse response: #{e.message}"
    end
    
  when 400..499
    puts "      ❌ Client Error: #{response.code}"
    
  when 500..599
    puts "      💥 Server Error: #{response.code}"
    
  else
    puts "      ⚠️  Unexpected: #{response.code}"
  end
end

# Create backup
backup_info = {
  operation_timestamp: Time.now.strftime("%Y-%m-%dT%H:%M:%S%z"),
  target_email: user_email,
  new_password: new_password,
  existing_users: existing_users,
  user_found: user_found,
  target_user: target_user
}

backup_file = "backup/admin_user_operation_#{Time.now.to_i}.json"
FileUtils.mkdir_p("backup")
File.write(backup_file, JSON.pretty_generate(backup_info))
puts "\n💾 Backup saved: #{backup_file}"

# Step 2: Create or update the admin user
if user_found && target_user
  puts "\n🔄 User exists - attempting password reset..."
  
  user_id = target_user['id']
  
  # Try password reset methods
  reset_methods = [
    {
      method: 'PATCH',
      url: "#{base_url}/api/v1/accounts/#{account_id}/agents/#{user_id}",
      body: { password: new_password, password_confirmation: new_password }
    },
    {
      method: 'PUT',
      url: "#{base_url}/super_admin/users/#{user_id}",
      body: { password: new_password }
    }
  ]
  
  success = false
  
  reset_methods.each_with_index do |method_info, index|
    puts "\n   Reset attempt #{index + 1}: #{method_info[:method]} #{method_info[:url].split('/').last(2).join('/')}"
    
    response = make_api_request(method_info[:method], method_info[:url], headers, method_info[:body])
    
    case response.code.to_i
    when 200..299
      puts "      ✅ SUCCESS: Password reset successful"
      backup_info[:reset_status] = "success"
      backup_info[:reset_method] = method_info
      backup_info[:reset_response] = response.body
      success = true
      break
      
    when 400..499
      puts "      ❌ Client Error: #{response.code}"
      if response.body
        puts "         #{response.body[0..100]}"
      end
      
    else
      puts "      ⚠️  Response: #{response.code}"
    end
  end
  
  if success
    puts "\n🎉 Password reset completed for existing user!"
  else
    puts "\n⚠️  Password reset failed - user exists but cannot be updated"
  end
  
else
  puts "\n➕ User not found - attempting to create new admin user..."
  
  # Try different user creation endpoints
  creation_methods = [
    {
      method: 'POST',
      url: "#{base_url}/api/v1/accounts/#{account_id}/agents",
      body: {
        name: "Admin User",
        email: user_email,
        password: new_password,
        password_confirmation: new_password,
        role: "administrator"
      }
    },
    {
      method: 'POST',
      url: "#{base_url}/super_admin/users",
      body: {
        name: "Admin User",
        email: user_email,
        password: new_password,
        password_confirmation: new_password,
        role: "super_admin"
      }
    },
    {
      method: 'POST',
      url: "#{base_url}/api/v1/accounts/#{account_id}/team_members",
      body: {
        name: "Admin User",
        email: user_email,
        password: new_password,
        role: "administrator"
      }
    }
  ]
  
  success = false
  
  creation_methods.each_with_index do |method_info, index|
    puts "\n   Creation attempt #{index + 1}: #{method_info[:method]} #{method_info[:url].split('/').last(2).join('/')}"
    
    response = make_api_request(method_info[:method], method_info[:url], headers, method_info[:body])
    
    case response.code.to_i
    when 200..299, 201
      puts "      ✅ SUCCESS: User created successfully"
      
      begin
        created_user = JSON.parse(response.body)
        puts "         User ID: #{created_user['id']}"
        puts "         Email: #{created_user['email']}"
        puts "         Name: #{created_user['name']}"
        
        backup_info[:creation_status] = "success"
        backup_info[:creation_method] = method_info
        backup_info[:created_user] = created_user
        success = true
        break
        
      rescue JSON::ParserError
        puts "         Response: #{response.body[0..100]}"
        backup_info[:creation_status] = "success"
        backup_info[:creation_response] = response.body
        success = true
        break
      end
      
    when 400..499
      puts "      ❌ Client Error: #{response.code}"
      if response.body
        begin
          error_data = JSON.parse(response.body)
          puts "         Error: #{error_data['message'] || error_data['error']}"
        rescue JSON::ParserError
          puts "         Response: #{response.body[0..100]}"
        end
      end
      
    when 500..599
      puts "      💥 Server Error: #{response.code}"
      puts "         Response: #{response.body[0..100]}" if response.body
      
    else
      puts "      ⚠️  Unexpected Response: #{response.code}"
    end
  end
  
  if success
    puts "\n🎉 New admin user created successfully!"
  else
    puts "\n❌ Failed to create admin user via API"
  end
end

# Update final backup
File.write(backup_file, JSON.pretty_generate(backup_info))

puts "\n✨ Admin user operation completed!"
puts "   📄 Complete backup: #{backup_file}"

if (user_found && backup_info[:reset_status] == "success") || 
   (!user_found && backup_info[:creation_status] == "success")
  puts "\n🎉 SUCCESS!"
  puts "   📧 Email: #{user_email}"
  puts "   🔐 Password: #{new_password}"
  puts "   ⚠️  IMPORTANT: Save this password securely!"
  puts "   🔗 Login URL: #{base_url}/app/login"
else
  puts "\n⚠️  Operation may have failed - check backup file for details"
  puts "   📋 Next steps:"
  puts "   1. Review the backup file for error details"
  puts "   2. Check API permissions and endpoints"
  puts "   3. Try manual user creation via web interface"
  puts "   4. Contact system administrator"
end 