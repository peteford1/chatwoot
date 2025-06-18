puts "🔍 Checking Platform Token Permissions..."
token = "PDcyku9tpAYnNytixsfmoCHo"
access_token = AccessToken.find_by(token: token)

if access_token.nil?
  puts "❌ Token not found!"
  exit 1
end

puts "✅ Token found - Type: #{access_token.owner_type}"

if access_token.owner_type == 'PlatformApp'
  platform_app = access_token.owner
  puts "🏢 Platform App: #{platform_app.name}"
  
  permissibles = platform_app.platform_app_permissibles.includes(:permissible)
  puts "🔐 Current permissions: #{permissibles.count}"
  
  if permissibles.empty?
    puts "❌ No permissions granted yet!"
  else
    permissibles.each do |perm|
      puts "   ✅ #{perm.permissible.class}: #{perm.permissible.name} (ID: #{perm.permissible.id})"
    end
  end
  
  puts "📊 Available Accounts:"
  Account.all.each do |account|
    has_permission = permissibles.any? { |p| p.permissible_id == account.id && p.permissible_type == 'Account' }
    status = has_permission ? "✅" : "❌"
    puts "   #{status} Account: #{account.name} (ID: #{account.id})"
  end
  
  # Check specifically for Account ID 1
  account_1 = Account.find_by(id: 1)
  if account_1
    has_perm = permissibles.any? { |p| p.permissible_id == 1 && p.permissible_type == 'Account' }
    if has_perm
      puts "✅ Has permission for Account ID 1"
    else
      puts "❌ Missing permission for Account ID 1 - needs to be granted!"
    end
  end
else
  puts "❌ Token is not for a Platform App"
end 