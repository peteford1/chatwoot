#!/bin/bash

echo "🚀 Setting up SuperAdmin user..."

# Create SuperAdmin user using Rails runner
bundle exec rails runner "
begin
  puts 'Creating SuperAdmin user...'
  
  # Check if SuperAdmin already exists
  existing_admin = User.find_by(email: 'admin@voicelinkai.com')
  if existing_admin
    puts 'SuperAdmin already exists: ' + existing_admin.email
    puts 'Type: ' + existing_admin.type.to_s
    exit 0
  end
  
  # Create new SuperAdmin
  super_admin = User.create!(
    name: 'Super Administrator',
    email: 'admin@voicelinkai.com',
    password: 'SuperAdmin123!',
    password_confirmation: 'SuperAdmin123!',
    type: 'SuperAdmin',
    confirmed_at: Time.current
  )
  
  puts '✅ SuperAdmin user created successfully!'
  puts 'ID: ' + super_admin.id.to_s
  puts 'Name: ' + super_admin.name
  puts 'Email: ' + super_admin.email
  puts 'Type: ' + super_admin.type
  
  # Create access token
  access_token = super_admin.create_access_token
  puts 'Access Token: ' + access_token.token
  
  puts ''
  puts '🔐 Login Details:'
  puts 'URL: https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/super_admin'
  puts 'Email: admin@voicelinkai.com'
  puts 'Password: SuperAdmin123!'
  
rescue => e
  puts '❌ Error creating SuperAdmin user: ' + e.message
  puts e.backtrace.first if e.backtrace
end
"

echo "✅ SuperAdmin setup complete!" 