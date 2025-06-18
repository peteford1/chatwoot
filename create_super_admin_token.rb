#!/usr/bin/env ruby

puts "🚀 Creating Super Admin Platform Token..."

# Create the platform app
platform_app = PlatformApp.create!(
  name: "Super Admin Platform App"
)

puts "✅ Platform App created successfully!"
puts "   ID: #{platform_app.id}"
puts "   Name: #{platform_app.name}"

# Get the access token (automatically created via AccessTokenable concern)
access_token = platform_app.access_token

puts "\n🔐 Super Admin Access Token:"
puts "   Token: #{access_token.token}"
puts "   Token ID: #{access_token.id}"

# Grant permissions for all existing accounts
Account.find_each do |account|
  permissible = platform_app.platform_app_permissibles.find_or_create_by!(
    permissible: account
  )
  puts "✅ Added permission for Account: #{account.name} (ID: #{account.id})"
end

puts "\n📋 Super Admin Token Summary:"
puts "   Platform App: #{platform_app.name}"
puts "   Access Token: #{access_token.token}"
puts "   Total Account Permissions: #{platform_app.platform_app_permissibles.count}"

puts "\n✨ Super admin platform token created successfully!" 