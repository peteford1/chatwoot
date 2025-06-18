#!/usr/bin/env ruby

# This script creates a platform token using Rails console approach
puts "Creating platform token for Storefront via Rails console..."

rails_commands = <<~RUBY
  # Find the account
  account = Account.find(1)
  puts "Found account: #{account.name}"
  
  # Create platform app
  platform_app = PlatformApp.create!(
    name: "Storefront Platform App",
    description: "Platform API access for Storefront integration",
    account: account
  )
  
  puts "Created Platform App:"
  puts "  ID: #{platform_app.id}"
  puts "  Name: #{platform_app.name}"
  puts "  Access Token: #{platform_app.access_token}"
  puts ""
  puts "━" * 60
  puts "STOREFRONT PLATFORM TOKEN:"
  puts platform_app.access_token
  puts "━" * 60
  puts ""
  puts "Use this token in API calls with header:"
  puts "api_access_token: #{platform_app.access_token}"
RUBY

# Write the commands to a temporary file
File.write('/tmp/create_platform_token.rb', rails_commands)

puts "Executing Rails console command..."
puts "Running: bundle exec rails console < /tmp/create_platform_token.rb"

# Execute the Rails console command
system("bundle exec rails console < /tmp/create_platform_token.rb")

# Clean up
File.delete('/tmp/create_platform_token.rb') if File.exist?('/tmp/create_platform_token.rb') 