#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'
require 'fileutils'
require 'securerandom'

puts "🔐 Resetting Password for admin@voicelinkai.com..."

# Configuration
base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
account_id = 1
api_token = 'baea8676c67aba47c08564ce'
user_email = 'admin@voicelinkai.com'

# Generate a secure new password
new_password = SecureRandom.alphanumeric(16) + "!1A"  # Ensure complexity requirements
puts "\n🎯 Password Reset Details:"
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

# Step 1: Find the user by email
puts "\n🔍 Finding user by email..."

users_url = "#{base_url}/api/v1/accounts/#{account_id}/users"
users_response = make_api_request('GET', users_url, headers)

user_id = nil
user_data = nil

if users_response.code.to_i == 200
  begin
    users_data = JSON.parse(users_response.body)
    users = users_data['payload'] || users_data
    
    target_user = users.find { |user| user['email'] == user_email }
    
    if target_user
      user_id = target_user['id']
      user_data = target_user
      puts "   ✅ Found user:"
      puts "      ID: #{user_id}"
      puts "      Name: #{target_user['name']}"
      puts "      Email: #{target_user['email']}"
      puts "      Role: #{target_user['role']}"
      puts "      Status: #{target_user['availability_status']}"
    else
      puts "   ❌ User not found with email: #{user_email}"
      
      # List all users for reference
      puts "\n📋 Available users:"
      users.each do |user|
        puts "      - ID: #{user['id']}, Email: #{user['email']}, Name: #{user['name']}"
      end
      exit 1
    end
    
  rescue JSON::ParserError => e
    puts "   ❌ Could not parse users response: #{e.message}"
    exit 1
  end
else
  puts "   ❌ Failed to fetch users: #{users_response.code}"
  puts "      Response: #{users_response.body}" if users_response.body
  exit 1
end

# Step 2: Create backup before password reset
puts "\n💾 Creating backup before password reset..."

backup_info = {
  reset_timestamp: Time.now.strftime("%Y-%m-%dT%H:%M:%S%z"),
  user_email: user_email,
  user_id: user_id,
  account_id: account_id,
  original_user_data: user_data,
  new_password: new_password,
  reason: "Password reset for admin user"
}

backup_file = "backup/password_reset_#{user_id}_#{Time.now.to_i}.json"
FileUtils.mkdir_p("backup")
File.write(backup_file, JSON.pretty_generate(backup_info))
puts "   📄 Backup saved: #{backup_file}"

# Step 3: Try different password reset methods
puts "\n🔐 Attempting password reset..."

reset_methods = [
  # Method 1: Update user profile with password
  {
    method: 'PATCH',
    url: "#{base_url}/api/v1/accounts/#{account_id}/users/#{user_id}",
    body: { password: new_password, password_confirmation: new_password }
  },
  # Method 2: Direct password update
  {
    method: 'PUT',
    url: "#{base_url}/api/v1/accounts/#{account_id}/users/#{user_id}",
    body: { password: new_password }
  },
  # Method 3: Password reset endpoint
  {
    method: 'POST',
    url: "#{base_url}/api/v1/accounts/#{account_id}/users/#{user_id}/reset_password",
    body: { password: new_password }
  }
]

success = false

reset_methods.each_with_index do |method_info, index|
  puts "\n   Attempt #{index + 1}: #{method_info[:method]} #{method_info[:url].split('/').last(2).join('/')}"
  
  response = make_api_request(method_info[:method], method_info[:url], headers, method_info[:body])
  
  case response.code.to_i
  when 200..299
    puts "   ✅ SUCCESS: Password reset successful"
    puts "      Status: #{response.code} #{response.message}"
    
    # Update backup with success
    backup_info[:reset_status] = "success"
    backup_info[:reset_method] = "#{method_info[:method]} #{method_info[:url]}"
    backup_info[:reset_response_code] = response.code.to_i
    backup_info[:reset_response_body] = response.body
    File.write(backup_file, JSON.pretty_generate(backup_info))
    
    success = true
    break
    
  when 400..499
    puts "   ❌ Client Error: #{response.code} #{response.message}"
    if response.body
      begin
        error_data = JSON.parse(response.body)
        puts "      Error: #{error_data['message'] || error_data['error']}"
      rescue JSON::ParserError
        puts "      Response: #{response.body[0..100]}"
      end
    end
    
  when 500..599
    puts "   💥 Server Error: #{response.code} #{response.message}"
    puts "      Response: #{response.body[0..100]}" if response.body
    
  else
    puts "   ⚠️  Unexpected Response: #{response.code} #{response.message}"
  end
end

# Step 4: Try alternative approach - Super Admin password reset
if !success
  puts "\n🔧 Trying Super Admin password reset approach..."
  
  # Try super admin endpoint
  super_admin_url = "#{base_url}/super_admin/users/#{user_id}"
  super_admin_response = make_api_request('PATCH', super_admin_url, headers, { password: new_password })
  
  case super_admin_response.code.to_i
  when 200..299
    puts "   ✅ SUCCESS: Super Admin password reset successful"
    puts "      Status: #{super_admin_response.code} #{super_admin_response.message}"
    
    backup_info[:reset_status] = "success"
    backup_info[:reset_method] = "PATCH #{super_admin_url}"
    backup_info[:reset_response_code] = super_admin_response.code.to_i
    backup_info[:reset_response_body] = super_admin_response.body
    File.write(backup_file, JSON.pretty_generate(backup_info))
    
    success = true
    
  else
    puts "   ❌ Super Admin approach failed: #{super_admin_response.code}"
    puts "      Response: #{super_admin_response.body[0..100]}" if super_admin_response.body
  end
end

# Step 5: Try Rails console approach (if API methods fail)
if !success
  puts "\n🛠️  API methods failed. Trying Rails console approach..."
  
  rails_script = <<~RUBY
    user = User.find_by(email: '#{user_email}')
    if user
      user.password = '#{new_password}'
      user.password_confirmation = '#{new_password}'
      if user.save
        puts "SUCCESS: Password updated for #{user_email}"
      else
        puts "ERROR: #{user.errors.full_messages.join(', ')}"
      end
    else
      puts "ERROR: User not found with email #{user_email}"
    end
  RUBY
  
  rails_script_file = "temp_password_reset_#{Time.now.to_i}.rb"
  File.write(rails_script_file, rails_script)
  
  puts "   📝 Created Rails script: #{rails_script_file}"
  puts "   🚀 Running Rails console command..."
  
  # Note: This would need to be run on the server, not locally
  puts "   ⚠️  Note: This needs to be run on the production server:"
  puts "      bundle exec rails runner #{rails_script_file}"
  
  backup_info[:rails_script] = {
    file: rails_script_file,
    content: rails_script,
    note: "Run this on production server if API methods fail"
  }
end

# Update final backup
File.write(backup_file, JSON.pretty_generate(backup_info))

puts "\n✨ Password reset process completed!"
puts "   📄 Complete backup: #{backup_file}"

if success
  puts "\n🎉 SUCCESS: Password reset completed!"
  puts "   📧 Email: #{user_email}"
  puts "   🔐 New Password: #{new_password}"
  puts "   ⚠️  IMPORTANT: Save this password securely!"
  puts "   🔗 Login URL: #{base_url}/app/login"
else
  puts "\n⚠️  Password reset via API failed!"
  puts "   📋 Next steps:"
  puts "   1. Check backup file for detailed error information"
  puts "   2. Try running the Rails script on the production server"
  puts "   3. Contact system administrator for manual password reset"
  puts "   4. Check user permissions and API token validity"
end

# Clean up temporary files
if defined?(rails_script_file) && File.exist?(rails_script_file)
  File.delete(rails_script_file)
  puts "   🧹 Cleaned up temporary script file"
end 