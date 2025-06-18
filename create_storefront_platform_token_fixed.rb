# Rails runner script to create platform token (fixed)
account = Account.find(1)
puts "Found account: #{account.name}"

# Create platform app without description field
platform_app = PlatformApp.create!(
  name: "Storefront Platform App",
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