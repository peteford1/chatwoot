#!/usr/bin/env ruby

# Script to create a Platform App for Multi-Tenant Frontend
# Run this script with: bundle exec ruby create_frontend_platform_app.rb

puts "Creating Platform App for Multi-Tenant Frontend..."

# Create the platform app
platform_app = PlatformApp.create!(
  name: "Multi-Tenant Frontend Application"
)

puts "✅ Platform App created successfully!"
puts "   ID: #{platform_app.id}"
puts "   Name: #{platform_app.name}"
puts "   Created at: #{platform_app.created_at}"

# Get the access token (automatically created via AccessTokenable concern)
access_token = platform_app.access_token

puts "\n🔐 Access Token Details:"
puts "   Token: #{access_token.token}"
puts "   Token ID: #{access_token.id}"

# Create permissibles for all existing accounts (for multi-tenant access)
Account.find_each do |account|
  permissible = platform_app.platform_app_permissibles.find_or_create_by!(
    permissible: account
  )
  puts "✅ Added permission for Account: #{account.name} (ID: #{account.id})"
end

puts "\n📋 Summary:"
puts "   Platform App: #{platform_app.name}"
puts "   Access Token: #{access_token.token}"
puts "   Permissions: #{platform_app.platform_app_permissibles.count} accounts"

puts "\n🔧 Usage in Frontend:"
puts "   Add this to your frontend environment variables:"
puts "   CHATWOOT_API_ACCESS_TOKEN=#{access_token.token}"
puts "   CHATWOOT_API_BASE_URL=https://voicelinkai-gateway.eastus.cloudapp.azure.com"

puts "\n📖 API Usage Examples:"
puts "   # Get all accounts"
puts "   curl -H 'api_access_token: #{access_token.token}' \\"
puts "        https://voicelinkai-gateway.eastus.cloudapp.azure.com/platform/api/v1/accounts"
puts ""
puts "   # Create a new account"  
puts "   curl -X POST -H 'api_access_token: #{access_token.token}' \\"
puts "        -H 'Content-Type: application/json' \\"
puts "        -d '{\"name\":\"New Tenant Account\"}' \\"
puts "        https://voicelinkai-gateway.eastus.cloudapp.azure.com/platform/api/v1/accounts"

puts "\n✨ Platform App created successfully for multi-tenant frontend!" 