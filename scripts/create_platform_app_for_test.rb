#!/usr/bin/env ruby

# Create Platform App for Test Environment Management
# This creates a platform app in the development environment that can manage the test environment

puts "🔧 Creating Platform App for Test Environment Management"
puts "=" * 60

# Create platform app in development environment
platform_app = PlatformApp.create!(
  name: 'VoiceLinkAI Test Environment Manager'
)

puts "✅ Platform App created successfully!"
puts "   ID: #{platform_app.id}"
puts "   Name: #{platform_app.name}"

# Get the access token
platform_token = platform_app.access_token.token

puts "\n🔑 Platform Token for Test Environment:"
puts "   Token: #{platform_token}"

puts "\n📋 Now you can use this token to manage the test environment via API calls:"
puts "\n# Create Account:"
puts "curl -X POST 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/platform/api/v1/accounts' \\"
puts "  -H 'Content-Type: application/json' \\"
puts "  -H 'api_access_token: #{platform_token}' \\"
puts "  -d '{\"name\": \"voicelinkai\", \"locale\": \"en\"}'"

puts "\n# Create User:"
puts "curl -X POST 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/platform/api/v1/users' \\"
puts "  -H 'Content-Type: application/json' \\"
puts "  -H 'api_access_token: #{platform_token}' \\"
puts "  -d '{\"name\": \"Root Owner\", \"email\": \"admin@voicelinkai.com\", \"password\": \"123@321Qq\"}'"

puts "\n✨ Platform app ready for test environment management!" 