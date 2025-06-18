# Check existing platform apps first
puts "Existing platform apps:"
PlatformApp.all.each do |app|
  puts "  ID: #{app.id}, Name: #{app.name}, Token: #{app.access_token}"
end

# Create platform app with minimal attributes
platform_app = PlatformApp.new
platform_app.name = "Storefront Platform App"
platform_app.account_id = 1  # Use account_id instead of account
platform_app.save!

puts "\nCreated Platform App:"
puts "  ID: #{platform_app.id}"
puts "  Name: #{platform_app.name}"
puts "  Access Token: #{platform_app.access_token}"
puts ""
puts "━" * 60
puts "STOREFRONT PLATFORM TOKEN:"
puts platform_app.access_token
puts "━" * 60 