# Create account and user for storefront integration
puts '🏪 Setting up Chatwoot Account for Storefront Integration'
puts '======================================================='
puts ''

# Create account
account = Account.create!(
  name: 'Storefront Account',
  status: 'active'
)
puts "✅ Created account: #{account.name} (ID: #{account.id})"

# Create user
user = User.create!(
  email: 'storeadmin@voicelinkai.com',
  password: 'Voicelink2024!',
  password_confirmation: 'Voicelink2024!',
  name: 'Store Administrator',
  confirmed_at: Time.current
)
puts "✅ Created user: #{user.email}"

# Create account user association
account_user = AccountUser.create!(
  account: account,
  user: user,
  role: 'administrator'
)
puts "✅ Associated user with account"

# Create platform app
platform_app = PlatformApp.create!(
  name: 'Storefront Platform App',
  account: account
)
puts "✅ Created platform app: #{platform_app.name}"

puts ''
puts '━' * 60
puts '🔑 STOREFRONT PLATFORM TOKEN:'
puts platform_app.access_token
puts '━' * 60
puts ''
puts '🎯 READY FOR TESTING!'
puts "Account ID: #{account.id}"
puts "User Email: #{user.email}"
puts "Platform Token: #{platform_app.access_token}"
puts ''
puts '📋 Storefront Environment Variables:'
puts "CHATWOOT_API_URL=https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
puts "CHATWOOT_PLATFORM_TOKEN=#{platform_app.access_token}"
puts "CHATWOOT_ACCOUNT_ID=#{account.id}" 