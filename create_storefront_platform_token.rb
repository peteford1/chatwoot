#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

# Configuration
BACKEND_URL = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
ACCOUNT_ID = 1
ADMIN_EMAIL = 'storeadmin@voicelinkai.com'
ADMIN_PASSWORD = 'Voicelink2024!'

def create_platform_token
  puts "Creating new platform token for Storefront..."
  
  # First, get an admin access token
  login_uri = URI("#{BACKEND_URL}/auth/sign_in")
  login_data = {
    email: ADMIN_EMAIL,
    password: ADMIN_PASSWORD
  }
  
  http = Net::HTTP.new(login_uri.host, login_uri.port)
  http.use_ssl = true
  
  login_request = Net::HTTP::Post.new(login_uri)
  login_request['Content-Type'] = 'application/json'
  login_request.body = login_data.to_json
  
  puts "Authenticating admin user..."
  login_response = http.request(login_request)
  
  if login_response.code != '200'
    puts "Login failed: #{login_response.code} - #{login_response.body}"
    return nil
  end
  
  login_result = JSON.parse(login_response.body)
  access_token = login_result.dig('data', 'access_token')
  
  if !access_token
    puts "Failed to get access token from login response"
    puts "Response: #{login_response.body}"
    return nil
  end
  
  puts "Successfully authenticated. Creating platform app..."
  
  # Create platform app
  platform_uri = URI("#{BACKEND_URL}/platform/api/v1/accounts/#{ACCOUNT_ID}/platform_apps")
  platform_data = {
    name: "Storefront Platform App",
    description: "Platform API access for Storefront integration"
  }
  
  platform_request = Net::HTTP::Post.new(platform_uri)
  platform_request['Content-Type'] = 'application/json'
  platform_request['api_access_token'] = access_token
  platform_request.body = platform_data.to_json
  
  platform_response = http.request(platform_request)
  
  if platform_response.code == '200' || platform_response.code == '201'
    result = JSON.parse(platform_response.body)
    token = result.dig('access_token')
    app_id = result.dig('id')
    
    puts "\n✅ SUCCESS! Platform token created:"
    puts "━" * 50
    puts "App Name: Storefront Platform App"
    puts "App ID: #{app_id}"
    puts "Platform Token: #{token}"
    puts "━" * 50
    puts "\nThis token can be used for Platform API calls with header:"
    puts "api_access_token: #{token}"
    
    return token
  else
    puts "Failed to create platform app: #{platform_response.code}"
    puts "Response: #{platform_response.body}"
    return nil
  end
  
rescue => e
  puts "Error creating platform token: #{e.message}"
  puts e.backtrace.first(5)
  return nil
end

# Execute
token = create_platform_token
exit(token ? 0 : 1) 