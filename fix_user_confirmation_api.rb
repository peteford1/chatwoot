#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'
require 'fileutils'

puts "🔧 Fixing User Confirmation via Platform API..."

# Configuration
base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
account_id = 1
api_token = 'baea8676c67aba47c08564ce'

# Users to fix
target_users = [
  { email: 'admin@voicelinkai.com', password: 'Admin123!@#', name: 'Original Admin' },
  { email: 'admin2@voicelinkai.com', password: 'VoiceLink2025!', name: 'New Admin' },
  { email: 'storeadmin@voicelinkai.com', password: 'Admin123!@#', name: 'Store Admin' }
]

puts "\n🎯 Using Platform API to Skip User Confirmation..."
puts "   This is the proper method according to Chatwoot's codebase"

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

# Step 1: Get all current users
puts "\n🔍 Getting current users..."

agents_url = "#{base_url}/api/v1/accounts/#{account_id}/agents"
agents_response = make_api_request('GET', agents_url, headers)

all_users = []

if agents_response.code.to_i == 200
  begin
    agents_data = JSON.parse(agents_response.body)
    
    if agents_data.is_a?(Hash) && agents_data['payload']
      all_users = agents_data['payload']
    elsif agents_data.is_a?(Array)
      all_users = agents_data
    end
    
    puts "   ✅ Found #{all_users.length} users in the system"
    
    unconfirmed_count = all_users.count { |user| user['confirmed_at'].nil? }
    puts "   ⚠️  #{unconfirmed_count} users are unconfirmed"
    
  rescue JSON::ParserError => e
    puts "   ❌ Could not parse response: #{e.message}"
    exit 1
  end
else
  puts "   ❌ Failed to get users: #{agents_response.code}"
  exit 1
end

# Step 2: Try the Platform API approach for each user
puts "\n🔧 Using Platform API to skip confirmation..."

successful_fixes = []
failed_fixes = []

all_users.each do |user|
  next if user['confirmed_at']  # Skip already confirmed users
  
  puts "\n   👤 Processing: #{user['name']} (#{user['email']})"
  puts "      User ID: #{user['id']}"
  puts "      Current Status: Unconfirmed"
  
  # Method 1: Try Platform API Users endpoint
  platform_url = "#{base_url}/platform/api/v1/users/#{user['id']}"
  
  # First, try to create/update via platform API (this should call skip_confirmation!)
  platform_body = {
    name: user['name'],
    email: user['email']
  }
  
  platform_response = make_api_request('PUT', platform_url, headers, platform_body)
  
  puts "      Platform API Response: #{platform_response.code}"
  
  case platform_response.code.to_i
  when 200..299
    puts "      ✅ Platform API call successful"
    
    begin
      updated_user = JSON.parse(platform_response.body)
      if updated_user['confirmed_at']
        puts "      🎉 User is now confirmed!"
        successful_fixes << user
      else
        puts "      ⚠️  User updated but still not confirmed"
        failed_fixes << user
      end
    rescue JSON::ParserError
      puts "      ✅ Platform API call successful (checking status...)"
      # We'll verify the status later
    end
    
  when 404
    puts "      ❌ Platform API endpoint not found"
    failed_fixes << user
    
  when 401, 403
    puts "      ❌ Platform API access denied"
    failed_fixes << user
    
  else
    puts "      ❌ Platform API failed: #{platform_response.code}"
    failed_fixes << user
  end
end

# Step 3: Alternative approach - try to create platform app permissibles
puts "\n🔧 Trying alternative platform API approach..."

# Check if we have a platform app
platform_apps_url = "#{base_url}/platform/api/v1/platform_apps"
platform_apps_response = make_api_request('GET', platform_apps_url, headers)

if platform_apps_response.code.to_i == 200
  begin
    platform_apps = JSON.parse(platform_apps_response.body)
    
    if platform_apps.any?
      platform_app = platform_apps.first
      puts "   ✅ Found platform app: #{platform_app['name']} (ID: #{platform_app['id']})"
      
      # Try to create users via platform app
      failed_fixes.each do |user|
        puts "\n   👤 Retrying: #{user['name']} (#{user['email']})"
        
        create_user_url = "#{base_url}/platform/api/v1/users"
        create_user_body = {
          name: user['name'],
          email: user['email'],
          password: target_users.find { |u| u[:email] == user['email'] }&.dig(:password) || 'TempPassword123!'
        }
        
        # Add platform app headers
        platform_headers = headers.merge({
          'X-Platform-App-Id' => platform_app['id'].to_s
        })
        
        create_response = make_api_request('POST', create_user_url, platform_headers, create_user_body)
        
        puts "      Create User Response: #{create_response.code}"
        
        if create_response.code.to_i == 200
          puts "      ✅ User created/updated via platform API"
          successful_fixes << user unless successful_fixes.include?(user)
          failed_fixes.delete(user)
        else
          puts "      ❌ Failed to create user via platform API"
        end
      end
      
    else
      puts "   ⚠️  No platform apps found"
    end
    
  rescue JSON::ParserError => e
    puts "   ❌ Could not parse platform apps response: #{e.message}"
  end
else
  puts "   ❌ Could not access platform apps: #{platform_apps_response.code}"
end

# Step 4: Final verification - check all users again
puts "\n🔍 Final verification of user statuses..."

final_agents_response = make_api_request('GET', agents_url, headers)

if final_agents_response.code.to_i == 200
  begin
    final_agents_data = JSON.parse(final_agents_response.body)
    
    if final_agents_data.is_a?(Hash) && final_agents_data['payload']
      final_users = final_agents_data['payload']
    elsif final_agents_data.is_a?(Array)
      final_users = final_agents_data
    end
    
    puts "\n   📊 Final Status Report:"
    
    confirmed_count = 0
    unconfirmed_count = 0
    
    final_users.each do |user|
      status = user['confirmed_at'] ? '✅' : '❌'
      puts "      #{status} #{user['email']} (ID: #{user['id']})"
      
      if user['confirmed_at']
        confirmed_count += 1
      else
        unconfirmed_count += 1
      end
    end
    
    puts "\n   📈 Summary:"
    puts "      ✅ Confirmed users: #{confirmed_count}"
    puts "      ❌ Unconfirmed users: #{unconfirmed_count}"
    
  rescue JSON::ParserError => e
    puts "   ❌ Could not parse final response: #{e.message}"
  end
end

# Step 5: Test login for target users
puts "\n🧪 Testing login for target users..."

target_users.each do |user_info|
  puts "\n   👤 Testing: #{user_info[:name]} (#{user_info[:email]})"
  
  login_url = "#{base_url}/auth/sign_in"
  login_body = {
    email: user_info[:email],
    password: user_info[:password]
  }
  
  login_headers = {
    'Content-Type' => 'application/json',
    'Accept' => 'application/json'
  }
  
  login_response = make_api_request('POST', login_url, login_headers, login_body)
  
  puts "      Login Response: #{login_response.code}"
  
  case login_response.code.to_i
  when 200..299
    puts "      ✅ LOGIN SUCCESS!"
    
    begin
      login_data = JSON.parse(login_response.body)
      if login_data['user']
        puts "         Logged in as: #{login_data['user']['name']}"
      end
    rescue JSON::ParserError
      puts "         Login successful (raw response)"
    end
    
  when 401
    puts "      ❌ Login failed: Invalid credentials"
    
  else
    puts "      ⚠️  Unexpected response: #{login_response.code}"
  end
end

# Step 6: Create backup and summary
backup_info = {
  fix_timestamp: Time.now.strftime("%Y-%m-%dT%H:%M:%S%z"),
  method_used: "Platform API skip_confirmation!",
  successful_fixes: successful_fixes.map { |u| { id: u['id'], email: u['email'], name: u['name'] } },
  failed_fixes: failed_fixes.map { |u| { id: u['id'], email: u['email'], name: u['name'] } },
  total_users_processed: all_users.length,
  target_users: target_users
}

backup_file = "backup/platform_api_confirmation_fix_#{Time.now.to_i}.json"
FileUtils.mkdir_p("backup")
File.write(backup_file, JSON.pretty_generate(backup_info))

puts "\n✨ Platform API confirmation fix completed!"
puts "   📄 Backup: #{backup_file}"

if successful_fixes.any?
  puts "\n🎉 SUCCESS: Fixed confirmation for #{successful_fixes.length} users!"
  puts "   ✅ Users fixed:"
  successful_fixes.each do |user|
    puts "      - #{user['name']} (#{user['email']})"
  end
  
elsif failed_fixes.any?
  puts "\n⚠️  Some users still need fixing:"
  failed_fixes.each do |user|
    puts "      - #{user['name']} (#{user['email']})"
  end
  
else
  puts "\n✅ All users appear to be confirmed already!"
end

puts "\n💡 NEXT STEPS:"
puts "   1. Try logging in with the credentials above"
puts "   2. If login still fails, the issue may be deeper in the authentication system"
puts "   3. Check application logs for more detailed error messages"
puts "   4. Consider checking email configuration (SMTP settings)"

puts "\n🔗 LOGIN DETAILS:"
target_users.each do |user_info|
  puts "   📧 #{user_info[:email]} / 🔐 #{user_info[:password]}"
end
puts "   🌐 URL: #{base_url}/app/login" 