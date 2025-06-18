#!/usr/bin/env ruby

# Create initial SuperAdmin user and account for test environment
puts "🚀 Creating initial SuperAdmin user for test environment..."
puts "Schema: #{ENV['DATABASE_SCHEMA'] || 'default'}"
puts "Database User: #{ENV['DATABASE_USER'] || 'default'}"
puts ""

begin
  # Create SuperAdmin user
  user = User.create!(
    name: 'Root Owner', 
    email: 'admin@voicelinkai.com', 
    password: '123@321Qq', 
    password_confirmation: '123@321Qq', 
    type: 'SuperAdmin', 
    confirmed_at: Time.current
  )
  puts "✅ Created SuperAdmin user: #{user.email} (ID: #{user.id})"

  # Create account
  account = Account.create!(name: 'voicelinkai')
  puts "✅ Created account: #{account.name} (ID: #{account.id})"

  # Link user to account
  account_user = AccountUser.create!(user: user, account: account, role: :administrator)
  puts "✅ Linked user to account as administrator"

  # Generate access token
  access_token = user.access_token.token
  puts ""
  puts "🎉 Test Environment Setup Complete!"
  puts "=" * 50
  puts "User ID: #{user.id}"
  puts "Account ID: #{account.id}"
  puts "Access Token: #{access_token}"
  puts "=" * 50

rescue => e
  puts "❌ Error creating user: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end 