#!/bin/bash

echo "🔧 Fixing SuperAdmin credentials..."

bundle exec rails runner "
admin_user = User.find(4)
puts 'Current user details:'
puts 'ID: ' + admin_user.id.to_s
puts 'Email: ' + admin_user.email
puts 'Type: ' + admin_user.type.to_s

# Update email and reset password
admin_user.email = 'admin@voicelinkai.com'
admin_user.password = 'SuperAdmin123!'
admin_user.password_confirmation = 'SuperAdmin123!'
admin_user.confirmed_at = Time.current
admin_user.save!

puts '✅ Updated email and password!'

# Delete old tokens and create new one
admin_user.access_tokens.destroy_all
access_token = admin_user.create_access_token

puts ''
puts '✅ New credentials:'
puts 'URL: https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/super_admin'
puts 'Email: admin@voicelinkai.com'
puts 'Password: SuperAdmin123!'
puts 'API Token: ' + access_token.token
"

echo "✅ SuperAdmin credentials fixed!" 