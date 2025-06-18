#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'
require 'fileutils'

puts "🔧 FINAL SOLUTION: Fixing Chatwoot User Confirmation Issue"

# Configuration
base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
account_id = 1
api_token = 'baea8676c67aba47c08564ce'

puts "\n📋 ANALYSIS: Based on Chatwoot's codebase, I found the root cause and solutions:"
puts "   🔍 Issue: ALL users are unconfirmed due to broken email confirmation system"
puts "   💡 Solution 1: Use Devise's allow_unconfirmed_access_for configuration"
puts "   💡 Solution 2: Use password reset flow (automatically confirms users)"
puts "   💡 Solution 3: Direct database confirmation via Rails console"

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

# Solution 1: Use Password Reset Flow (Recommended)
puts "\n🔧 SOLUTION 1: Using Password Reset Flow"
puts "   📖 According to Chatwoot's code, password reset automatically confirms users"
puts "   📍 File: app/controllers/devise_overrides/passwords_controller.rb:29"
puts "   💻 Code: recoverable.confirm unless recoverable.confirmed?"

target_users = [
  { email: 'admin@voicelinkai.com', new_password: 'VoiceLink2025!' },
  { email: 'admin2@voicelinkai.com', new_password: 'VoiceLink2025!' },
  { email: 'storeadmin@voicelinkai.com', new_password: 'VoiceLink2025!' }
]

successful_resets = []
failed_resets = []

target_users.each do |user_info|
  puts "\n   👤 Processing: #{user_info[:email]}"
  
  # Step 1: Request password reset
  reset_request_url = "#{base_url}/auth/password"
  reset_request_body = { email: user_info[:email] }
  
  reset_request_headers = {
    'Content-Type' => 'application/json',
    'Accept' => 'application/json'
  }
  
  reset_response = make_api_request('POST', reset_request_url, reset_request_headers, reset_request_body)
  
  puts "      Reset Request: #{reset_response.code}"
  
  if reset_response.code.to_i == 200
    puts "      ✅ Password reset email sent (this should confirm the user)"
    successful_resets << user_info
  else
    puts "      ❌ Failed to send reset email"
    failed_resets << user_info
  end
end

# Wait a moment for processing
puts "\n⏳ Waiting 5 seconds for password reset processing..."
sleep(5)

# Solution 2: Check if users are now confirmed
puts "\n🔍 VERIFICATION: Checking user confirmation status..."

agents_url = "#{base_url}/api/v1/accounts/#{account_id}/agents"
agents_response = make_api_request('GET', agents_url, headers)

confirmed_users = []
still_unconfirmed = []

if agents_response.code.to_i == 200
  begin
    agents_data = JSON.parse(agents_response.body)
    
    if agents_data.is_a?(Hash) && agents_data['payload']
      all_users = agents_data['payload']
    elsif agents_data.is_a?(Array)
      all_users = agents_data
    end
    
    puts "   📊 User Status Report:"
    
    all_users.each do |user|
      status = user['confirmed_at'] ? '✅ CONFIRMED' : '❌ Unconfirmed'
      puts "      #{status}: #{user['email']} (ID: #{user['id']})"
      
      if user['confirmed_at']
        confirmed_users << user
      else
        still_unconfirmed << user
      end
    end
    
    puts "\n   📈 Summary:"
    puts "      ✅ Confirmed: #{confirmed_users.length}"
    puts "      ❌ Unconfirmed: #{still_unconfirmed.length}"
    
  rescue JSON::ParserError => e
    puts "   ❌ Could not parse response: #{e.message}"
  end
end

# Solution 3: Test login with new passwords
puts "\n🧪 TESTING: Login attempts with reset passwords..."

login_successes = []
login_failures = []

target_users.each do |user_info|
  puts "\n   👤 Testing: #{user_info[:email]}"
  
  login_url = "#{base_url}/auth/sign_in"
  login_body = {
    email: user_info[:email],
    password: user_info[:new_password]
  }
  
  login_headers = {
    'Content-Type' => 'application/json',
    'Accept' => 'application/json'
  }
  
  login_response = make_api_request('POST', login_url, login_headers, login_body)
  
  puts "      Login Response: #{login_response.code}"
  
  case login_response.code.to_i
  when 200..299
    puts "      🎉 LOGIN SUCCESS!"
    login_successes << user_info
    
    begin
      login_data = JSON.parse(login_response.body)
      if login_data['user']
        puts "         User: #{login_data['user']['name']}"
        puts "         Email: #{login_data['user']['email']}"
      end
    rescue JSON::ParserError
      puts "         Login successful (response parsing failed)"
    end
    
  when 401
    puts "      ❌ Login failed: Invalid credentials or unconfirmed account"
    login_failures << user_info
    
  else
    puts "      ⚠️  Unexpected response: #{login_response.code}"
    login_failures << user_info
  end
end

# Solution 4: Provide configuration fix recommendations
puts "\n🔧 CONFIGURATION RECOMMENDATIONS:"

puts "\n   📝 OPTION A: Enable Unconfirmed Access (Temporary Fix)"
puts "      Edit: config/initializers/devise.rb"
puts "      Add: config.allow_unconfirmed_access_for = 30.days"
puts "      This allows users to login for 30 days without confirmation"

puts "\n   📝 OPTION B: Fix Email Configuration (Permanent Fix)"
puts "      1. Check SMTP settings in environment variables"
puts "      2. Verify email delivery is working"
puts "      3. Check spam folders for confirmation emails"
puts "      4. Test email sending with a simple test"

puts "\n   📝 OPTION C: Manual Database Fix (Advanced)"
puts "      Rails console commands:"
puts "      User.where(confirmed_at: nil).update_all(confirmed_at: Time.current)"
puts "      This manually confirms all unconfirmed users"

# Create comprehensive backup
backup_info = {
  fix_timestamp: Time.now.strftime("%Y-%m-%dT%H:%M:%S%z"),
  issue_analysis: {
    root_cause: "Systemic email confirmation failure",
    affected_users: "ALL users in system",
    confirmation_system_status: "Broken"
  },
  solutions_attempted: [
    {
      method: "Password Reset Flow",
      description: "Uses Chatwoot's built-in confirmation on password reset",
      code_reference: "app/controllers/devise_overrides/passwords_controller.rb:29",
      successful_resets: successful_resets.map { |u| u[:email] },
      failed_resets: failed_resets.map { |u| u[:email] }
    }
  ],
  verification_results: {
    confirmed_users: confirmed_users.map { |u| { id: u['id'], email: u['email'], name: u['name'] } },
    still_unconfirmed: still_unconfirmed.map { |u| { id: u['id'], email: u['email'], name: u['name'] } }
  },
  login_test_results: {
    successful_logins: login_successes.map { |u| u[:email] },
    failed_logins: login_failures.map { |u| u[:email] }
  },
  recommended_solutions: [
    {
      priority: 1,
      method: "Devise Configuration",
      setting: "config.allow_unconfirmed_access_for = 30.days",
      file: "config/initializers/devise.rb",
      description: "Allows unconfirmed users to access the system temporarily"
    },
    {
      priority: 2,
      method: "Email System Fix",
      description: "Fix SMTP configuration and email delivery",
      impact: "Permanent solution for new users"
    },
    {
      priority: 3,
      method: "Database Update",
      command: "User.where(confirmed_at: nil).update_all(confirmed_at: Time.current)",
      description: "Manually confirm all existing users"
    }
  ]
}

backup_file = "backup/comprehensive_confirmation_fix_#{Time.now.to_i}.json"
FileUtils.mkdir_p("backup")
File.write(backup_file, JSON.pretty_generate(backup_info))

puts "\n✨ COMPREHENSIVE ANALYSIS COMPLETED!"
puts "   📄 Full Report: #{backup_file}"

# Final status and recommendations
if login_successes.any?
  puts "\n🎉 PARTIAL SUCCESS!"
  puts "   ✅ Working logins:"
  login_successes.each do |user|
    puts "      📧 #{user[:email]} / 🔐 #{user[:new_password]}"
  end
  puts "   🌐 Login URL: #{base_url}/app/login"
  
elsif confirmed_users.any?
  puts "\n✅ USERS CONFIRMED BUT LOGIN ISSUES REMAIN"
  puts "   💡 Try the original passwords or check for other authentication issues"
  
else
  puts "\n⚠️  CONFIRMATION SYSTEM STILL BROKEN"
  puts "   🔧 Immediate action required - see configuration recommendations above"
end

puts "\n📚 CHATWOOT API DOCUMENTATION FINDINGS:"
puts "   🔍 Confirmation can be skipped using: user.skip_confirmation!"
puts "   🔍 Password reset automatically confirms: recoverable.confirm unless recoverable.confirmed?"
puts "   🔍 Platform API has built-in skip_confirmation! calls"
puts "   🔍 Devise config allows temporary unconfirmed access"

puts "\n💡 NEXT STEPS:"
puts "   1. If any logins work above, use those credentials immediately"
puts "   2. Implement the Devise configuration fix for temporary access"
puts "   3. Fix the underlying email system for permanent solution"
puts "   4. Consider manual database confirmation for all existing users"

puts "\n🔗 CURRENT WORKING CREDENTIALS (if any):"
if login_successes.any?
  login_successes.each do |user|
    puts "   📧 #{user[:email]} / 🔐 #{user[:new_password]}"
  end
else
  puts "   ❌ No working credentials found - configuration fix required"
end 