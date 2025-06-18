#!/usr/bin/env ruby

puts "🚀 Creating SuperAdmin User..."

begin
  # Create a SuperAdmin user
  super_admin = User.create!(
    name: 'Super Administrator',
    email: 'admin@voicelinkai.com',
    password: 'SuperAdmin123!',
    password_confirmation: 'SuperAdmin123!',
    type: 'SuperAdmin',
    confirmed_at: Time.current
  )

  puts "✅ SuperAdmin user created successfully!"
  puts "   ID: #{super_admin.id}"
  puts "   Name: #{super_admin.name}"
  puts "   Email: #{super_admin.email}"
  puts "   Type: #{super_admin.type}"
  puts "   Access Token: #{super_admin.access_token.token}"

  puts "\n🔐 Login Details:"
  puts "   URL: https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/super_admin"
  puts "   Email: admin@voicelinkai.com"
  puts "   Password: SuperAdmin123!"

  puts "\n📋 API Access Token:"
  puts "   Token: #{super_admin.access_token.token}"
  puts "   Use this token for API calls with header: api_access_token"

rescue ActiveRecord::RecordInvalid => e
  puts "❌ Error creating SuperAdmin user:"
  puts "   #{e.message}"
  puts "   Errors: #{e.record.errors.full_messages.join(', ')}"
  
  # Check if user already exists
  existing_user = User.find_by(email: 'admin@voicelinkai.com')
  if existing_user
    puts "\n🔍 User already exists:"
    puts "   ID: #{existing_user.id}"
    puts "   Name: #{existing_user.name}"
    puts "   Email: #{existing_user.email}"
    puts "   Type: #{existing_user.type}"
    
    if existing_user.type != 'SuperAdmin'
      puts "\n🔄 Upgrading existing user to SuperAdmin..."
      existing_user.update!(type: 'SuperAdmin')
      puts "✅ User upgraded to SuperAdmin!"
    end
    
    puts "   Access Token: #{existing_user.access_token.token}"
  end

rescue => e
  puts "💥 Unexpected error: #{e.message}"
  puts "   Backtrace: #{e.backtrace.first(5).join("\n   ")}"
end

puts "\n✨ SuperAdmin creation process completed!" 