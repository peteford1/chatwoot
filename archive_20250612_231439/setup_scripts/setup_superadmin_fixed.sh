#!/bin/bash

echo "🚀 Setting up SuperAdmin user (Fixed Version)..."

# Create SuperAdmin user using Rails runner
bundle exec rails runner "
begin
  puts 'Checking for existing SuperAdmin users...'
  
  # Check if any SuperAdmin already exists
  existing_admin = User.find_by(email: 'admin@voicelinkai.com')
  if existing_admin
    puts '✅ SuperAdmin already exists!'
    puts 'ID: ' + existing_admin.id.to_s
    puts 'Name: ' + existing_admin.name.to_s
    puts 'Email: ' + existing_admin.email
    puts 'Type: ' + existing_admin.type.to_s
    
    # Update to SuperAdmin if not already
    if existing_admin.type != 'SuperAdmin'
      existing_admin.update!(type: 'SuperAdmin')
      puts '✅ Updated user type to SuperAdmin'
    end
    
    # Create access token if needed
    if existing_admin.access_tokens.empty?
      access_token = existing_admin.create_access_token
      puts 'New Access Token: ' + access_token.token
    else
      puts 'Existing Access Token: ' + existing_admin.access_tokens.first.token
    end
    
    puts ''
    puts '🔐 Login Details:'
    puts 'URL: https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/super_admin'
    puts 'Email: admin@voicelinkai.com'
    puts 'Password: SuperAdmin123!'
    exit 0
  end
  
  # Check for any user with similar uid/provider combination
  existing_uid_user = User.find_by(uid: 'admin@voicelinkai.com', provider: 'email')
  if existing_uid_user
    puts 'Found existing user with same UID/provider:'
    puts 'ID: ' + existing_uid_user.id.to_s
    puts 'Name: ' + existing_uid_user.name.to_s
    puts 'Email: ' + existing_uid_user.email
    puts 'Type: ' + existing_uid_user.type.to_s
    
    # Update this user to be our SuperAdmin
    existing_uid_user.update!(
      name: 'Super Administrator',
      email: 'admin@voicelinkai.com',
      type: 'SuperAdmin',
      confirmed_at: Time.current
    )
    
    puts '✅ Updated existing user to SuperAdmin!'
    
    # Create access token
    access_token = existing_uid_user.create_access_token
    puts 'Access Token: ' + access_token.token
    
    puts ''
    puts '🔐 Login Details:'
    puts 'URL: https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/super_admin'
    puts 'Email: admin@voicelinkai.com'
    puts 'Password: SuperAdmin123!'
    exit 0
  end
  
  puts 'No existing SuperAdmin found. Creating new one...'
  
  # Create new SuperAdmin with unique uid
  super_admin = User.create!(
    name: 'Super Administrator',
    email: 'admin@voicelinkai.com',
    password: 'SuperAdmin123!',
    password_confirmation: 'SuperAdmin123!',
    type: 'SuperAdmin',
    confirmed_at: Time.current,
    uid: 'superadmin_' + Time.current.to_i.to_s,
    provider: 'email'
  )
  
  puts '✅ SuperAdmin user created successfully!'
  puts 'ID: ' + super_admin.id.to_s
  puts 'Name: ' + super_admin.name
  puts 'Email: ' + super_admin.email
  puts 'Type: ' + super_admin.type
  puts 'UID: ' + super_admin.uid.to_s
  
  # Create access token
  access_token = super_admin.create_access_token
  puts 'Access Token: ' + access_token.token
  
  puts ''
  puts '🔐 Login Details:'
  puts 'URL: https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/super_admin'
  puts 'Email: admin@voicelinkai.com'
  puts 'Password: SuperAdmin123!'
  
rescue => e
  puts '❌ Error: ' + e.message
  puts 'Backtrace: ' + e.backtrace.first if e.backtrace
  
  # Let's also check what users exist
  puts ''
  puts 'Current users in database:'
  User.all.each do |user|
    puts '- ID: ' + user.id.to_s + ', Email: ' + user.email.to_s + ', Type: ' + user.type.to_s + ', UID: ' + user.uid.to_s + ', Provider: ' + user.provider.to_s
  end
end
"

echo "✅ SuperAdmin setup complete!" 