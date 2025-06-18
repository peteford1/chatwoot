#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

puts "🔄 PASSWORD RESET TOKEN RECOVERY"
puts "=" * 50

BASE_URL = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'

# Known email addresses to try
KNOWN_EMAILS = [
  'admin@voicelinkai.com',
  'admin@chatwoot.local',
  'test@chatwoot.local',
  'user@chatwoot.local',
  'support@voicelinkai.com'
]

def make_request(method, path, body = nil)
  uri = URI("#{BASE_URL}#{path}")
  
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  http.read_timeout = 30
  
  case method.upcase
  when 'GET'
    request = Net::HTTP::Get.new(uri)
  when 'POST'
    request = Net::HTTP::Post.new(uri)
    request.body = body if body
    request['Content-Type'] = 'application/json'
  end
  
  begin
    response = http.request(request)
    {
      status: response.code.to_i,
      body: response.body,
      headers: response.to_hash
    }
  rescue => e
    {
      status: 0,
      body: "Connection error: #{e.message}",
      headers: {}
    }
  end
end

def trigger_password_reset(email)
  puts "\n📧 Triggering password reset for: #{email}"
  
  reset_data = {
    email: email
  }
  
  response = make_request('POST', '/auth/password', reset_data.to_json)
  
  if response[:status] == 200
    puts "✅ Password reset email sent successfully"
    puts "📬 Check email for reset link"
    return true
  elsif response[:status] == 404
    puts "❌ Email not found in system"
    return false
  else
    puts "❌ Password reset failed: #{response[:status]} - #{response[:body][0..100]}"
    return false
  end
end

def check_user_exists_via_api(email)
  puts "\n🔍 Checking if user exists: #{email}"
  
  # Try to trigger password reset to see if user exists
  reset_response = trigger_password_reset(email)
  
  if reset_response
    puts "✅ User exists and password reset triggered"
    puts "📋 Next steps:"
    puts "   1. Check email for password reset link"
    puts "   2. Click the link to reset password"
    puts "   3. After login, go to Profile > API Access Token"
    puts "   4. Copy the API token for future use"
    return true
  else
    puts "❌ User does not exist or email failed"
    return false
  end
end

def provide_manual_instructions
  puts "\n" + "=" * 60
  puts "📋 MANUAL TOKEN RECOVERY INSTRUCTIONS"
  puts "=" * 60
  
  puts "\n🔐 If you have web access to any user account:"
  puts "1. Login to: #{BASE_URL}/app/login"
  puts "2. Go to Settings > Profile"
  puts "3. Look for 'API Access Token' section"
  puts "4. Copy the token (it's auto-generated for each user)"
  
  puts "\n🏢 For Platform tokens:"
  puts "1. Login as Super Admin: #{BASE_URL}/super_admin/sign_in"
  puts "2. Go to Platform Apps section"
  puts "3. Create new Platform App or view existing ones"
  puts "4. Copy the access token"
  
  puts "\n📧 If you have email access:"
  puts "1. Use password reset for known email addresses"
  puts "2. Reset password and login"
  puts "3. Navigate to profile to get API token"
  
  puts "\n🗄️ If you have database access:"
  puts "1. Run: ruby create_emergency_tokens_azure_db.rb"
  puts "2. This will create new users and tokens directly"
  
  puts "\n⚠️  Last resort - Container console:"
  puts "1. Run: bash azure_console_token_generation.sh"
  puts "2. This requires Azure CLI access to container"
end

# Main execution
puts "🚀 Starting password reset recovery process..."

successful_resets = []

KNOWN_EMAILS.each do |email|
  if check_user_exists_via_api(email)
    successful_resets << email
  end
  
  # Small delay between requests
  sleep 1
end

puts "\n" + "=" * 60
puts "📊 RECOVERY SUMMARY"
puts "=" * 60

if successful_resets.any?
  puts "✅ Password reset triggered for #{successful_resets.length} email(s):"
  successful_resets.each { |email| puts "   - #{email}" }
  
  puts "\n📬 Check these email inboxes for password reset links"
  puts "🔗 After resetting password, login and go to Profile > API Access Token"
else
  puts "❌ No successful password resets triggered"
  puts "💡 This could mean:"
  puts "   - None of the tested emails exist in the system"
  puts "   - Email service is not configured"
  puts "   - Network/connectivity issues"
end

provide_manual_instructions

puts "\n🎯 RECOMMENDED NEXT STEPS:"
puts "1. Try database access method (most reliable)"
puts "2. Try Azure container console method"
puts "3. Try super admin web interface"
puts "4. Check email for any password reset links" 