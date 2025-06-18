#!/usr/bin/env ruby

# Script to create a Platform App for Multi-Tenant Frontend in Production
# This should be run on the production Chatwoot backend

puts "🚀 Creating Platform App for Multi-Tenant Frontend in Production..."

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

puts "\n📋 Production Summary:"
puts "   Platform App: #{platform_app.name}"
puts "   Access Token: #{access_token.token}"
puts "   Permissions: #{platform_app.platform_app_permissibles.count} accounts"

puts "\n🌐 Frontend Environment Variables:"
puts "   CHATWOOT_API_ACCESS_TOKEN=#{access_token.token}"
puts "   CHATWOOT_API_BASE_URL=https://voicelinkai-gateway.eastus.cloudapp.azure.com"

puts "\n📚 Available Platform API Endpoints:"
puts "   POST /platform/api/v1/accounts                    - Create new account"
puts "   GET  /platform/api/v1/accounts/{id}               - Get account details"
puts "   PATCH /platform/api/v1/accounts/{id}              - Update account"
puts "   DELETE /platform/api/v1/accounts/{id}             - Delete account"
puts "   POST /platform/api/v1/users                       - Create new user"
puts "   GET  /platform/api/v1/users/{id}                  - Get user details"
puts "   GET  /platform/api/v1/users/{id}/login            - Get SSO login link"
puts "   PATCH /platform/api/v1/users/{id}                 - Update user"
puts "   DELETE /platform/api/v1/users/{id}                - Delete user"
puts "   GET  /platform/api/v1/accounts/{id}/account_users - List account users"
puts "   POST /platform/api/v1/accounts/{id}/account_users - Add user to account"

puts "\n🔧 Usage Examples:"
puts "   # Create a new tenant account"
puts "   curl -X POST -H 'api_access_token: #{access_token.token}' \\"
puts "        -H 'Content-Type: application/json' \\"
puts "        -d '{\"name\":\"Tenant Corp\"}' \\"
puts "        https://voicelinkai-gateway.eastus.cloudapp.azure.com/platform/api/v1/accounts"
puts ""
puts "   # Create a new user"
puts "   curl -X POST -H 'api_access_token: #{access_token.token}' \\"
puts "        -H 'Content-Type: application/json' \\"
puts "        -d '{\"name\":\"John Doe\",\"email\":\"john@example.com\",\"password\":\"SecurePass123!\"}' \\"
puts "        https://voicelinkai-gateway.eastus.cloudapp.azure.com/platform/api/v1/users"
puts ""
puts "   # Get SSO login link for a user"
puts "   curl -H 'api_access_token: #{access_token.token}' \\"
puts "        https://voicelinkai-gateway.eastus.cloudapp.azure.com/platform/api/v1/users/1/login"

puts "\n✨ Multi-tenant platform app ready for production!" 