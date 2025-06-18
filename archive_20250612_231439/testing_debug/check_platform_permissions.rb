#!/usr/bin/env ruby

puts "🔍 Checking Platform Token Permissions..."
puts "=" * 50

token = "PDcyku9tpAYnNytixsfmoCHo"
access_token = AccessToken.find_by(token: token)

if access_token.nil?
  puts "❌ Token not found!"
  exit 1
end

puts "✅ Token found:"
puts "   ID: #{access_token.id}"
puts "   Owner Type: #{access_token.owner_type}"
puts "   Owner ID: #{access_token.owner_id}"

if access_token.owner_type == 'PlatformApp'
  platform_app = access_token.owner
  puts "\n🏢 Platform App Details:"
  puts "   Name: #{platform_app.name}"
  puts "   ID: #{platform_app.id}"
  
  puts "\n🔐 Current Permissions:"
  permissibles = platform_app.platform_app_permissibles.includes(:permissible)
  
  if permissibles.empty?
    puts "   ❌ No permissions granted yet!"
  else
    permissibles.each do |perm|
      puts "   ✅ #{perm.permissible.class}: #{perm.permissible.name} (ID: #{perm.permissible.id})"
    end
  end
  
  puts "\n📊 Available Accounts:"
  Account.all.each do |account|
    has_permission = permissibles.any? { |p| p.permissible_id == account.id && p.permissible_type == 'Account' }
    status = has_permission ? "✅" : "❌"
    puts "   #{status} Account: #{account.name} (ID: #{account.id})"
  end
  
  puts "\n🛠 To Grant Permission to Account ID 1:"
  account_1 = Account.find_by(id: 1)
  if account_1
    has_perm = permissibles.any? { |p| p.permissible_id == 1 && p.permissible_type == 'Account' }
    if has_perm
      puts "   ✅ Already has permission for Account ID 1"
    else
      puts "   ❌ Missing permission for Account ID 1"
      puts "   💡 Run this to grant access:"
      puts "      platform_app.platform_app_permissibles.find_or_create_by!(permissible: Account.find(1))"
    end
  else
    puts "   ❌ Account ID 1 not found!"
  end
  
else
  puts "❌ Token is not for a Platform App"
end

puts "\n" + "=" * 50 