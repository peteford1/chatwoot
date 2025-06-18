#!/usr/bin/env ruby

puts "🚀 Granting Platform Token Permissions to All Accounts..."
puts "=" * 60

token = ENV.fetch('API_ACCESS_TOKEN', nil)
if token.nil?
  puts "❌ API_ACCESS_TOKEN environment variable not set!"
  exit 1
end

access_token = AccessToken.find_by(token: token)

if access_token.nil?
  puts "❌ Token not found!"
  exit 1
end

if access_token.owner_type != 'PlatformApp'
  puts "❌ Token is not for a Platform App"
  exit 1
end

platform_app = access_token.owner
puts "✅ Found Platform App: #{platform_app.name} (ID: #{platform_app.id})"

puts "\n📋 Current Permissions:"
current_permissions = platform_app.platform_app_permissibles.includes(:permissible)
if current_permissions.empty?
  puts "   ❌ No permissions currently granted"
else
  current_permissions.each do |perm|
    puts "   ✅ #{perm.permissible.class}: #{perm.permissible.name} (ID: #{perm.permissible.id})"
  end
end

puts "\n🏢 Available Accounts:"
accounts = Account.all
accounts.each do |account|
  puts "   📊 Account: #{account.name} (ID: #{account.id})"
end

puts "\n🔐 Granting permissions to all accounts..."
granted_count = 0
accounts.each do |account|
  permission = platform_app.platform_app_permissibles.find_or_create_by!(permissible: account)
  if permission.persisted?
    puts "   ✅ Granted access to: #{account.name} (ID: #{account.id})"
    granted_count += 1
  else
    puts "   ❌ Failed to grant access to: #{account.name} (ID: #{account.id})"
  end
end

puts "\n📊 Summary:"
puts "   🎯 Platform App: #{platform_app.name}"
puts "   🔑 Access Token: #{token}"
puts "   📈 Permissions Granted: #{granted_count} accounts"
puts "   🌐 Total Accounts: #{accounts.count}"

puts "\n✅ Platform token now has access to all accounts!"
puts "\n🔧 Test your token with:"
puts "   curl -H 'api_access_token: #{token}' \\"
puts "        https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/accounts/1/conversations"

puts "\n" + "=" * 60 