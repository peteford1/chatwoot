#!/bin/bash

echo "🔐 Resetting SuperAdmin password and generating new API token..."

# Reset SuperAdmin password using Rails runner
bundle exec rails runner "
begin
  puts 'Finding SuperAdmin user...'
  
  # Find the SuperAdmin user
  admin_user = User.find_by(email: 'admin@voicelinkai.com')
  
  if admin_user.nil?
    puts '❌ SuperAdmin user not found!'
    exit 1
  end
  
  puts 'Found SuperAdmin user:'
  puts 'ID: ' + admin_user.id.to_s
  puts 'Name: ' + admin_user.name.to_s
  puts 'Email: ' + admin_user.email
  puts 'Type: ' + admin_user.type.to_s
  puts 'Current confirmed_at: ' + admin_user.confirmed_at.to_s
  
  # Reset password
  new_password = 'SuperAdmin123!'
  admin_user.password = new_password
  admin_user.password_confirmation = new_password
  admin_user.confirmed_at = Time.current
  admin_user.type = 'SuperAdmin'
  
  if admin_user.save!
    puts '✅ Password reset successfully!'
  else
    puts '❌ Failed to reset password: ' + admin_user.errors.full_messages.join(', ')
    exit 1
  end
  
  # Delete old access tokens
  admin_user.access_tokens.destroy_all
  puts '🗑️ Deleted old access tokens'
  
  # Create new access token
  access_token = admin_user.create_access_token
  puts '✅ New access token created: ' + access_token.token
  
  puts ''
  puts '🔐 Updated Login Details:'
  puts 'URL: https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/super_admin'
  puts 'Email: admin@voicelinkai.com'
  puts 'Password: SuperAdmin123!'
  puts 'API Token: ' + access_token.token
  
  puts ''
  puts '🧪 Testing API access...'
  
rescue => e
  puts '❌ Error: ' + e.message
  puts 'Backtrace: ' + e.backtrace.first if e.backtrace
end
"

echo "✅ Password reset complete!" 