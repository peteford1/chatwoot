# Get existing platform app token
existing_app = PlatformApp.find(2)
puts "Existing Platform App:"
puts "  ID: #{existing_app.id}"
puts "  Name: #{existing_app.name}"
puts "  Access Token: #{existing_app.access_token.token}"
puts ""

# Check the actual model structure first
puts "PlatformApp attributes:"
puts PlatformApp.attribute_names.inspect
puts ""

# Try to create a new one with just the name
begin
  platform_app = PlatformApp.create!(name: "Storefront Platform App")
  
  puts "Created new Platform App:"
  puts "  ID: #{platform_app.id}"
  puts "  Name: #{platform_app.name}"
  puts "  Access Token: #{platform_app.access_token.token}"
  puts ""
  puts "━" * 60
  puts "NEW STOREFRONT PLATFORM TOKEN:"
  puts platform_app.access_token.token
  puts "━" * 60
  
rescue => e
  puts "Error creating new platform app: #{e.message}"
  puts ""
  puts "━" * 60
  puts "EXISTING PLATFORM TOKEN (can be used for Storefront):"
  puts existing_app.access_token.token
  puts "━" * 60
end

puts ""
puts "Use this token in API calls with header:"
puts "api_access_token: [TOKEN_VALUE]" 