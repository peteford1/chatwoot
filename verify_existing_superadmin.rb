#!/usr/bin/env ruby

puts "🔍 Verifying Existing SuperAdmin: admin@voicelinkai.com"

begin
  # Try to find the existing SuperAdmin user
  admin_email = 'admin@voicelinkai.com'
  
  puts "\n🔎 Searching for SuperAdmin user..."
  puts "   Email: #{admin_email}"
  
  # First check if user exists at all
  user = User.find_by(email: admin_email)
  
  if user
    puts "\n✅ User found!"
    puts "   ID: #{user.id}"
    puts "   Name: #{user.name}"
    puts "   Email: #{user.email}"
    puts "   Type: #{user.type}"
    puts "   Confirmed: #{user.confirmed_at ? 'Yes' : 'No'}"
    puts "   Created: #{user.created_at}"
    puts "   Last Sign In: #{user.last_sign_in_at || 'Never'}"
    
    # Check if it's actually a SuperAdmin
    if user.type == 'SuperAdmin'
      puts "\n🎯 Confirmed: This is a SuperAdmin user!"
      
      # Check access token
      if user.access_token
        puts "   Access Token: #{user.access_token.token}"
      else
        puts "   ⚠️  No access token found"
      end
      
      # Check if confirmed
      if user.confirmed_at
        puts "   ✅ Account is confirmed"
      else
        puts "   ⚠️  Account is NOT confirmed - this could cause login issues"
        puts "   💡 You may need to confirm the account"
      end
      
      puts "\n🌐 Super Admin Panel Access:"
      puts "   Gateway URL: https://voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io/super_admin"
      puts "   Direct URL: https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/super_admin"
      puts "   Email: #{admin_email}"
      puts "   Password: [You need to know/reset this]"
      
      puts "\n🔧 If you can't login, possible issues:"
      puts "   1. Password needs to be reset"
      puts "   2. Account needs to be confirmed"
      puts "   3. Super admin routes not properly configured"
      puts "   4. Application not running in production mode"
      
    else
      puts "\n⚠️  User exists but is NOT a SuperAdmin!"
      puts "   Current type: #{user.type || 'Regular User'}"
      puts "   💡 Need to promote this user to SuperAdmin"
      
      # Offer to promote
      puts "\n🔄 To promote to SuperAdmin, run:"
      puts "   User.find_by(email: '#{admin_email}').update!(type: 'SuperAdmin')"
    end
    
  else
    puts "\n❌ No user found with email: #{admin_email}"
    puts "   The user may have been deleted or email is different"
    
    # Check for similar emails
    similar_users = User.where("email ILIKE ?", "%voicelinkai%")
    if similar_users.any?
      puts "\n🔍 Found similar emails:"
      similar_users.each do |u|
        puts "   - #{u.email} (#{u.type || 'User'})"
      end
    end
    
    # Check all SuperAdmin users
    all_super_admins = User.where(type: 'SuperAdmin')
    puts "\n👥 All SuperAdmin users in system: #{all_super_admins.count}"
    all_super_admins.each do |admin|
      puts "   - #{admin.email} (ID: #{admin.id})"
    end
  end

rescue => e
  puts "💥 Error verifying SuperAdmin: #{e.message}"
  puts "   This script needs to run with database access"
  puts "   Try running on the Azure instance or with proper DB connection"
end

puts "\n✨ SuperAdmin verification completed!" 