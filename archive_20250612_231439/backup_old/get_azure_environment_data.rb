#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

puts "🚀 Getting Users, Inboxes, and Accounts from Azure Environment..."
puts "=" * 60

# Azure backend URL
AZURE_BACKEND_URL = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
SUPER_ADMIN_TOKEN = 'SamnuRSUjB4ZpktAqhLqxjeZ'

# Function to make API call
def make_api_call(endpoint, token = nil, method = 'GET', body = nil)
  url = "#{AZURE_BACKEND_URL}#{endpoint}"
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  
  case method.upcase
  when 'GET'
    request = Net::HTTP::Get.new(uri)
  when 'POST'
    request = Net::HTTP::Post.new(uri)
    request.body = body.to_json if body
  end
  
  request['Content-Type'] = 'application/json'
  request['api_access_token'] = token if token
  
  puts "📡 API Call: #{method} #{url}"
  
  begin
    response = http.request(request)
    puts "📊 Response Code: #{response.code}"
    
    if response.code.start_with?('2')
      data = JSON.parse(response.body) rescue response.body
      puts "✅ Success"
      return data
    else
      puts "❌ Error: #{response.body}"
      return nil
    end
  rescue => e
    puts "❌ Exception: #{e.message}"
    return nil
  end
end

puts "\n🔍 Step 1: Testing Basic API Connectivity..."
api_info = make_api_call('/api')
if api_info
  puts "✅ Backend is responding"
  puts "   Version: #{api_info['version']}"
  puts "   Timestamp: #{api_info['timestamp']}"
else
  puts "❌ Backend is not responding"
  exit 1
end

puts "\n🏢 Step 2: Attempting to Get Accounts..."

# Try different account endpoints
account_endpoints = [
  '/platform/api/v1/accounts',
  '/api/v1/accounts',
  '/super_admin/accounts'
]

accounts_data = nil
account_endpoints.each do |endpoint|
  puts "\n🔍 Trying endpoint: #{endpoint}"
  accounts_data = make_api_call(endpoint, SUPER_ADMIN_TOKEN)
  break if accounts_data
end

if accounts_data && accounts_data.is_a?(Array)
  puts "\n📋 ACCOUNTS FOUND (#{accounts_data.length}):"
  accounts_data.each_with_index do |account, index|
    puts "#{index + 1}. ID: #{account['id']}, Name: #{account['name']}"
    puts "   Status: #{account['status'] || 'N/A'}"
    puts "   Locale: #{account['locale'] || 'N/A'}"
    puts "   Created: #{account['created_at'] || 'N/A'}"
    puts ""
  end
  
  # For each account, try to get users and inboxes
  accounts_data.each do |account|
    account_id = account['id']
    account_name = account['name']
    
    puts "\n" + "=" * 50
    puts "🏢 ACCOUNT: #{account_name} (ID: #{account_id})"
    puts "=" * 50
    
    # Try to get agents/users for this account
    puts "\n👥 Getting Users/Agents..."
    user_endpoints = [
      "/api/v1/accounts/#{account_id}/agents",
      "/api/v1/accounts/#{account_id}/users",
      "/platform/api/v1/accounts/#{account_id}/account_users"
    ]
    
    users_found = false
    user_endpoints.each do |endpoint|
      puts "🔍 Trying: #{endpoint}"
      users_data = make_api_call(endpoint, SUPER_ADMIN_TOKEN)
      
      if users_data && users_data.is_a?(Array) && users_data.length > 0
        puts "✅ Found #{users_data.length} users:"
        users_data.each_with_index do |user, index|
          name = user['name'] || user['display_name'] || 'N/A'
          email = user['email'] || 'N/A'
          role = user['role'] || user['availability'] || 'N/A'
          puts "  #{index + 1}. #{name} (#{email}) - #{role}"
        end
        users_found = true
        break
      end
    end
    
    puts "❌ No users found for this account" unless users_found
    
    # Try to get inboxes for this account
    puts "\n📥 Getting Inboxes..."
    inbox_endpoints = [
      "/api/v1/accounts/#{account_id}/inboxes",
      "/platform/api/v1/accounts/#{account_id}/inboxes"
    ]
    
    inboxes_found = false
    inbox_endpoints.each do |endpoint|
      puts "🔍 Trying: #{endpoint}"
      inboxes_data = make_api_call(endpoint, SUPER_ADMIN_TOKEN)
      
      if inboxes_data && inboxes_data.is_a?(Array) && inboxes_data.length > 0
        puts "✅ Found #{inboxes_data.length} inboxes:"
        inboxes_data.each_with_index do |inbox, index|
          name = inbox['name'] || 'N/A'
          channel_type = inbox['channel_type'] || 'N/A'
          status = inbox['status'] || 'N/A'
          puts "  #{index + 1}. #{name} (#{channel_type}) - #{status}"
        end
        inboxes_found = true
        break
      end
    end
    
    puts "❌ No inboxes found for this account" unless inboxes_found
  end
  
else
  puts "❌ No accounts found or invalid response format"
  
  # Try to get some basic system information
  puts "\n🔍 Trying to get system information..."
  
  # Try super admin endpoints
  super_admin_endpoints = [
    '/super_admin',
    '/super_admin/dashboard',
    '/installation/onboarding'
  ]
  
  super_admin_endpoints.each do |endpoint|
    puts "\n🔍 Trying: #{endpoint}"
    data = make_api_call(endpoint, SUPER_ADMIN_TOKEN)
    if data
      puts "✅ Got response from #{endpoint}"
      puts data.inspect if data.is_a?(Hash)
    end
  end
end

puts "\n" + "=" * 60
puts "✨ Azure Environment Data Retrieval Complete!"
puts "=" * 60 