#!/usr/bin/env ruby

puts "🔐 Resetting Password for admin@voicelinkai.com (Direct Method)..."

# Configuration
user_email = 'admin@voicelinkai.com'

# Generate a secure new password
require 'securerandom'
new_password = SecureRandom.alphanumeric(16) + "!1A"  # Ensure complexity requirements

puts "\n🎯 Password Reset Details:"
puts "   Email: #{user_email}"
puts "   New Password: #{new_password}"

puts "\n🔍 Finding and updating user..."

begin
  # Find user by email
  user = User.find_by(email: user_email)
  
  if user
    puts "   ✅ Found user:"
    puts "      ID: #{user.id}"
    puts "      Name: #{user.name}"
    puts "      Email: #{user.email}"
    puts "      Role: #{user.role if user.respond_to?(:role)}"
    puts "      Created: #{user.created_at}"
    
    # Create backup info
    backup_info = {
      reset_timestamp: Time.now.strftime("%Y-%m-%dT%H:%M:%S%z"),
      user_id: user.id,
      user_email: user.email,
      user_name: user.name,
      old_password_digest: user.password_digest,
      new_password: new_password,
      method: "Rails console direct"
    }
    
    # Save backup
    require 'fileutils'
    require 'json'
    backup_file = "backup/password_reset_direct_#{user.id}_#{Time.now.to_i}.json"
    FileUtils.mkdir_p("backup")
    File.write(backup_file, JSON.pretty_generate(backup_info))
    puts "   💾 Backup saved: #{backup_file}"
    
    # Reset password
    puts "\n🔐 Resetting password..."
    
    user.password = new_password
    user.password_confirmation = new_password
    
    if user.save
      puts "   ✅ SUCCESS: Password updated successfully!"
      puts "      User ID: #{user.id}"
      puts "      Email: #{user.email}"
      puts "      New Password: #{new_password}"
      
      # Update backup with success
      backup_info[:reset_status] = "success"
      backup_info[:new_password_digest] = user.password_digest
      File.write(backup_file, JSON.pretty_generate(backup_info))
      
      puts "\n🎉 Password reset completed!"
      puts "   📧 Email: #{user_email}"
      puts "   🔐 New Password: #{new_password}"
      puts "   ⚠️  IMPORTANT: Save this password securely!"
      puts "   📄 Backup: #{backup_file}"
      
    else
      puts "   ❌ ERROR: Failed to save password"
      puts "      Errors: #{user.errors.full_messages.join(', ')}"
      
      backup_info[:reset_status] = "failed"
      backup_info[:errors] = user.errors.full_messages
      File.write(backup_file, JSON.pretty_generate(backup_info))
    end
    
  else
    puts "   ❌ User not found with email: #{user_email}"
    
    # List all users for reference
    puts "\n📋 Available users:"
    User.all.each do |u|
      puts "      - ID: #{u.id}, Email: #{u.email}, Name: #{u.name}"
    end
  end
  
rescue => e
  puts "   💥 ERROR: #{e.message}"
  puts "      #{e.class}: #{e.backtrace.first}"
end

puts "\n✨ Password reset process completed!" 