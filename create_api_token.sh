#!/bin/bash

echo "🔑 Creating new API token for SuperAdmin..."

bundle exec rails runner "
admin_user = User.find(4)
puts 'SuperAdmin user:'
puts 'ID: ' + admin_user.id.to_s
puts 'Email: ' + admin_user.email
puts 'Type: ' + admin_user.type.to_s

# Create new access token
access_token = admin_user.create_access_token
puts ''
puts '✅ New API token created!'
puts 'Token: ' + access_token.token

puts ''
puts '🔐 Complete Login Details:'
puts 'URL: https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/super_admin'
puts 'Email: admin@voicelinkai.com'
puts 'Password: SuperAdmin123!'
puts 'API Token: ' + access_token.token
"

echo "✅ API token created successfully!" 