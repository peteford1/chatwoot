# Rails Console Commands for Creating SMS Test Admin
# Copy and paste these commands one by one into the Rails console

# Step 1: Create a new user
user = User.create!(
  name: "SMS Test Admin",
  email: "sms_test_admin_#{SecureRandom.hex(4)}@example.com",
  password: "TestPassword123!",
  confirmed_at: Time.current
)

puts "✅ Created user: #{user.name} (ID: #{user.id})"
puts "✅ Email: #{user.email}"

# Step 2: Add user to account as administrator
account = Account.find(1)
account_user = AccountUser.create!(
  account: account,
  user: user,
  role: "administrator"
)

puts "✅ Added user to account as administrator"

# Step 3: Create API token for the user
token = AccessToken.create!(
  owner: user,
  token: SecureRandom.hex(32)
)

puts "✅ Created API token"
puts "=" * 60
puts "COPY THIS TOKEN:"
puts token.token
puts "=" * 60

# Step 4: Test the token works
puts "Testing token..."
puts "User ID: #{user.id}"
puts "Token: #{token.token}"
puts "Account ID: #{account.id}" 