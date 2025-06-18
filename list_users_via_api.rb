#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

puts "🚀 Listing Active Users via Chatwoot API..."

# First, create or find a platform app for API access
platform_app = PlatformApp.find_or_create_by!(name: "User List Platform App")
access_token = platform_app.access_token

puts "✅ Platform App Token: #{access_token.token}"

# Grant permissions for all existing accounts if not already granted
Account.find_each do |account|
  permissible = platform_app.platform_app_permissibles.find_or_create_by!(
    permissible: account
  )
  puts "✅ Added permission for Account: #{account.name} (ID: #{account.id})"
end

puts "\n📋 Making API calls to list users..."

# Get the base URL from environment or use localhost
base_url = ENV['FRONTEND_URL'] || 'http://localhost:3000'
api_token = access_token.token

# Function to make API call
def make_api_call(url, token)
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = (uri.scheme == 'https')
  
  request = Net::HTTP::Get.new(uri)
  request['api_access_token'] = token
  request['Content-Type'] = 'application/json'
  
  response = http.request(request)
  
  puts "📡 API Call: #{url}"
  puts "📊 Response Code: #{response.code}"
  
  if response.code == '200'
    JSON.parse(response.body)
  else
    puts "❌ Error: #{response.body}"
    nil
  end
end

# Try different endpoints to get user information
Account.find_each do |account|
  puts "\n🏢 Account: #{account.name} (ID: #{account.id})"
  
  # Try agents endpoint
  agents_url = "#{base_url}/api/v1/accounts/#{account.id}/agents"
  agents_data = make_api_call(agents_url, api_token)
  
  if agents_data
    puts "👥 Agents (#{agents_data.length}):"
    agents_data.each do |agent|
      status = agent['availability'] || 'unknown'
      puts "  • #{agent['name']} (#{agent['email']}) - #{status}"
    end
  end
  
  # Try account users endpoint via platform API
  account_users_url = "#{base_url}/platform/api/v1/accounts/#{account.id}/account_users"
  account_users_data = make_api_call(account_users_url, api_token)
  
  if account_users_data
    puts "👤 Account Users (#{account_users_data.length}):"
    account_users_data.each do |user|
      puts "  • User ID: #{user['user_id']}, Role: #{user['role']}"
    end
  end
end

puts "\n✨ User listing completed!" 