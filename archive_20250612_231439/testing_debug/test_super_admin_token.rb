#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

# Configuration
CHATWOOT_URL = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
TOKEN = 'baea8676c67aba47c08564ce'

def test_endpoint(path, method = 'GET', token_header = 'api_access_token')
  uri = URI("#{CHATWOOT_URL}#{path}")
  
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true if uri.scheme == 'https'
  
  if method == 'GET'
    request = Net::HTTP::Get.new(uri)
  else
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
  end
  
  request[token_header] = TOKEN
  
  begin
    response = http.request(request)
    puts "#{method} #{path}"
    puts "  Status: #{response.code} #{response.message}"
    
    if response.body && response.body.length < 200
      puts "  Body: #{response.body}"
    elsif response.body
      puts "  Body: #{response.body[0..100]}..."
    end
    puts ""
    
    return response.code.to_i
  rescue => e
    puts "#{method} #{path}"
    puts "  Error: #{e.message}"
    puts ""
    return 0
  end
end

puts "🔍 Testing Super Admin Token: #{TOKEN}"
puts "🌐 Chatwoot URL: #{CHATWOOT_URL}"
puts "=" * 60
puts ""

# Test various endpoints
endpoints = [
  '/api/v1/accounts',
  '/api/v1/profile',
  '/platform/api/v1/accounts',
  '/super_admin/accounts',
  '/super_admin/api/v1/accounts'
]

endpoints.each do |endpoint|
  test_endpoint(endpoint)
end

puts "💡 Manual Account Creation Steps:"
puts "1. Go to: #{CHATWOOT_URL}/super_admin"
puts "2. Login with:"
puts "   Email: admin@voicelinkai.com"
puts "   Password: SuperAdmin123!"
puts "3. Navigate to 'Accounts' section"
puts "4. Click 'New Account' button"
puts "5. Fill in:"
puts "   - Account Name: VoiceLink AI"
puts "   - Locale: English (en)"
puts "6. Click 'Create Account'"
puts ""
puts "🎯 After creating the account:"
puts "1. Note the Account ID"
puts "2. Create users for the account"
puts "3. Set up inboxes and channels" 