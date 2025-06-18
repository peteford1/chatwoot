#!/usr/bin/env ruby

# Rails runner script to create a stable platform token
# Run with: bundle exec rails runner create_stable_platform_token_rails.rb

puts "🔍 CHECKING EXISTING PLATFORM TOKENS..."
puts "=" * 60

# Check existing platform apps
existing_apps = PlatformApp.includes(:access_token).order(created_at: :desc)

if existing_apps.any?
  puts "📋 Found #{existing_apps.count} existing platform app(s):"
  existing_apps.each do |app|
    puts "   ID: #{app.id}"
    puts "   Name: #{app.name}"
    puts "   Token: #{app.access_token&.token}"
    puts "   Created: #{app.created_at}"
    puts "   Permissions: #{app.platform_app_permissibles.count} accounts"
    puts "   " + "-" * 40
  end
  
  # Test the most recent token
  latest_app = existing_apps.first
  if latest_app.access_token
    latest_token = latest_app.access_token.token
    puts "\n🧪 Testing latest token: #{latest_token}"
    
    # Test the token via API call
    require 'net/http'
    require 'json'
    require 'uri'
    
    begin
      uri = URI("https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/platform/api/v1/accounts")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 10
      request = Net::HTTP::Get.new(uri)
      request['api_access_token'] = latest_token
      
      response = http.request(request)
      
      if response.code.to_i < 400
        puts "✅ Latest token WORKS! No need to create new one."
        puts "🔑 STABLE PLATFORM TOKEN: #{latest_token}"
        puts "=" * 60
        puts "\n📝 This token:"
        puts "   • Does NOT expire"
        puts "   • Has platform-level permissions"
        puts "   • Can access #{latest_app.platform_app_permissibles.count} accounts"
        puts "   • Should be used for application integrations"
        puts "\n🧪 Test with:"
        puts "curl -H 'api_access_token: #{latest_token}' \\"
        puts "     'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/platform/api/v1/accounts'"
        exit 0
      else
        puts "❌ Latest token failed: #{response.code} - #{response.message}"
        puts "   Response: #{response.body[0..200]}"
      end
    rescue => e
      puts "❌ Token test error: #{e.message}"
    end
  else
    puts "❌ Latest app has no access token"
  end
else
  puts "❌ No existing platform apps found"
end

puts "\n🔧 CREATING NEW STABLE PLATFORM TOKEN..."
puts "=" * 60

begin
  # Create new platform app
  app_name = "Stable API Platform App - #{Time.now.strftime('%Y%m%d_%H%M%S')}"
  
  platform_app = PlatformApp.create!(
    name: app_name
  )
  
  puts "✅ Platform App created:"
  puts "   ID: #{platform_app.id}"
  puts "   Name: #{platform_app.name}"
  puts "   Created: #{platform_app.created_at}"
  
  # Access token is automatically created via AccessTokenable concern
  access_token = platform_app.access_token
  
  if access_token
    puts "✅ Access Token created:"
    puts "   Token ID: #{access_token.id}"
    puts "   Token: #{access_token.token}"
    
    # Add permissions for all accounts
    Account.find_each do |account|
      platform_app.platform_app_permissibles.find_or_create_by!(
        permissible: account
      )
      puts "✅ Added permission for Account: #{account.name} (ID: #{account.id})"
    end
    
    puts "\n" + "=" * 60
    puts "🎉 STABLE PLATFORM TOKEN CREATED!"
    puts "=" * 60
    puts "Token: #{access_token.token}"
    puts "=" * 60
    puts "\n📝 This token:"
    puts "   • Does NOT expire"
    puts "   • Has platform-level permissions"
    puts "   • Can access #{platform_app.platform_app_permissibles.count} accounts"
    puts "   • Should be used for application integrations"
    puts "\n🧪 Test with:"
    puts "curl -H 'api_access_token: #{access_token.token}' \\"
    puts "     'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/platform/api/v1/accounts'"
    
    # Test the new token immediately
    puts "\n🧪 Testing new token..."
    require 'net/http'
    require 'json'
    require 'uri'
    
    begin
      uri = URI("https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/platform/api/v1/accounts")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 10
      request = Net::HTTP::Get.new(uri)
      request['api_access_token'] = access_token.token
      
      response = http.request(request)
      
      if response.code.to_i < 400
        puts "✅ NEW TOKEN WORKS PERFECTLY!"
        data = JSON.parse(response.body) rescue nil
        if data && data.is_a?(Array)
          puts "   Found #{data.length} accounts accessible"
        end
      else
        puts "❌ New token test failed: #{response.code} - #{response.message}"
        puts "   Response: #{response.body[0..200]}"
      end
    rescue => e
      puts "❌ New token test error: #{e.message}"
    end
    
  else
    puts "❌ Failed to create access token"
  end
  
rescue => e
  puts "❌ Error creating platform app: #{e.message}"
  puts "   #{e.backtrace.first}"
end 