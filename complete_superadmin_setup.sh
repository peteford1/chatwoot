#!/bin/bash

echo "🚀 Complete SuperAdmin Setup..."

bundle exec rails runner "
begin
  # Find the existing user
  admin_user = User.find(4)
  puts 'Found existing user:'
  puts 'ID: ' + admin_user.id.to_s
  puts 'Current Email: ' + admin_user.email
  puts 'Type: ' + admin_user.type.to_s
  
  # Force update the email using direct SQL to bypass validations
  ActiveRecord::Base.connection.execute(\"UPDATE users SET email = 'admin@voicelinkai.com' WHERE id = 4\")
  
  # Reload the user to get updated data
  admin_user.reload
  
  # Update password and other fields
  admin_user.password = 'SuperAdmin123!'
  admin_user.password_confirmation = 'SuperAdmin123!'
  admin_user.confirmed_at = Time.current
  admin_user.type = 'SuperAdmin'
  admin_user.save!(validate: false)
  
  puts ''
  puts '✅ User updated successfully!'
  puts 'New Email: ' + admin_user.email
  puts 'Type: ' + admin_user.type.to_s
  puts 'Confirmed: ' + admin_user.confirmed_at.to_s
  
  # Create a new access token
  access_token = admin_user.create_access_token
  
  puts ''
  puts '🔐 SuperAdmin Login Credentials:'
  puts '================================'
  puts 'Login URL: https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/super_admin/sign_in'
  puts 'Email: admin@voicelinkai.com'
  puts 'Password: SuperAdmin123!'
  puts ''
  puts '🔑 API Access:'
  puts '=============='
  puts 'API Token: ' + access_token.token
  puts 'Test API: curl -H \"api_access_token: ' + access_token.token + '\" https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/profile'
  
rescue => e
  puts '❌ Error: ' + e.message
  puts e.backtrace.first if e.backtrace
end
"

echo ""
echo "✅ SuperAdmin setup complete!"
echo "You can now login to the SuperAdmin panel with the credentials shown above." 