#!/usr/bin/env ruby

puts "=== CHATWOOT ADMIN USER CHECK ==="
puts "Date: #{Time.current}"

# Check for SuperAdmin users
super_admins = User.where(type: 'SuperAdmin')
puts "\n🔍 SuperAdmin Users Found: #{super_admins.count}"

if super_admins.any?
  puts "\n✅ Existing SuperAdmin Users:"
  super_admins.each do |admin|
    puts "  - ID: #{admin.id}"
    puts "    Name: #{admin.name}"
    puts "    Email: #{admin.email}"
    puts "    Confirmed: #{admin.confirmed?}"
    puts "    Created: #{admin.created_at}"
    puts ""
  end
else
  puts "\n❌ No SuperAdmin users found!"
end

# Check for regular accounts
accounts = Account.where(status: :active)
puts "\n🏢 Active Accounts Found: #{accounts.count}"

if accounts.any?
  puts "\n✅ Existing Active Accounts:"
  accounts.each do |account|
    puts "  - ID: #{account.id}"
    puts "    Name: #{account.name}"
    puts "    Status: #{account.status}"
    puts "    Created: #{account.created_at}"
    
    # Check account users
    account_users = AccountUser.where(account: account).joins(:user)
    puts "    Users: #{account_users.count}"
    account_users.each do |au|
      puts "      * #{au.user.name} (#{au.user.email}) - Role: #{au.role}"
    end
    puts ""
  end
else
  puts "\n❌ No active accounts found!"
end

# Check total users
total_users = User.count
confirmed_users = User.confirmed.count
puts "\n👥 User Summary:"
puts "  Total Users: #{total_users}"
puts "  Confirmed Users: #{confirmed_users}"
puts "  Unconfirmed Users: #{total_users - confirmed_users}"

# Provide creation instructions
puts "\n" + "="*50
puts "📋 ADMIN USER CREATION INSTRUCTIONS"
puts "="*50

if super_admins.empty?
  puts "\n🚀 To create a SuperAdmin user, run:"
  puts "rails runner \"User.create!(name: 'Admin User', email: 'admin@voicelinkai.com', password: 'Password123!', type: 'SuperAdmin', confirmed_at: Time.current)\""
end

if accounts.empty?
  puts "\n🏢 To create an account with admin user, run:"
  puts "rails runner \"AccountBuilder.new(account_name: 'VoiceLinkAI', email: 'admin@voicelinkai.com', confirmed: true, user_full_name: 'Admin User', user_password: 'Password123!', super_admin: false, locale: 'en').perform\""
end

puts "\n🌐 Access URLs:"
puts "  Main App: https://voicelinkai.com"
puts "  SuperAdmin: https://voicelinkai.com/super_admin"
puts "  API: https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1"

puts "\n✅ Script completed!" 