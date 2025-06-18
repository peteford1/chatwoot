#!/usr/bin/env ruby

# Script to update storeadmin@voicelinkai.com password directly in Azure PostgreSQL
# Created: 2025-01-06 20:37:00 UTC
# Reason: User requested password reset to 'password'

require 'pg'
require 'bcrypt'

# Database connection details
DB_HOST = 'chatwoot-db.postgres.database.azure.com'
DB_NAME = 'chatwoot'
DB_USER = 'chatwootuser'
DB_PASSWORD = 'Password123'

begin
  puts "🔌 Connecting to Azure PostgreSQL database..."
  puts "   Host: #{DB_HOST}"
  puts "   Database: #{DB_NAME}"
  puts "   User: #{DB_USER}"
  
  conn = PG.connect(
    host: DB_HOST,
    dbname: DB_NAME,
    user: DB_USER,
    password: DB_PASSWORD,
    sslmode: 'require'
  )
  
  puts "✅ Database connection successful!"
  
  # Find the user
  email = 'storeadmin@voicelinkai.com'
  puts "\n🔍 Looking for user: #{email}"
  
  result = conn.exec_params(
    "SELECT id, email, name, type, encrypted_password FROM users WHERE email = $1",
    [email]
  )
  
  if result.ntuples == 0
    puts "❌ User not found: #{email}"
    exit 1
  end
  
  user_data = result[0]
  user_id = user_data['id']
  current_name = user_data['name']
  current_type = user_data['type']
  old_password_hash = user_data['encrypted_password']
  
  puts "✅ Found user:"
  puts "   ID: #{user_id}"
  puts "   Email: #{email}"
  puts "   Name: #{current_name}"
  puts "   Type: #{current_type}"
  puts "   Old password hash: #{old_password_hash[0..20]}..." if old_password_hash
  
  # Generate new BCrypt password hash
  new_password = 'password'
  puts "\n🔐 Generating new BCrypt password hash..."
  
  new_encrypted_password = BCrypt::Password.create(new_password).to_s
  puts "   New password hash: #{new_encrypted_password[0..20]}..."
  
  # Create backup record
  backup_timestamp = Time.now.utc.strftime('%Y-%m-%d %H:%M:%S UTC')
  backup_info = {
    user_id: user_id,
    email: email,
    old_password_hash: old_password_hash,
    change_timestamp: backup_timestamp,
    change_reason: 'User requested password reset'
  }
  
  puts "\n📋 BACKUP INFO (save this for rollback if needed):"
  puts "   User ID: #{backup_info[:user_id]}"
  puts "   Email: #{backup_info[:email]}"
  puts "   Old password hash: #{backup_info[:old_password_hash]}"
  puts "   Change timestamp: #{backup_info[:change_timestamp]}"
  puts "   Reason: #{backup_info[:change_reason]}"
  
  # Update the password
  puts "\n💾 Updating password in database..."
  
  update_result = conn.exec_params(
    "UPDATE users SET encrypted_password = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2",
    [new_encrypted_password, user_id]
  )
  
  if update_result.cmd_tuples == 1
    puts "✅ Password updated successfully!"
    puts "   Email: #{email}"
    puts "   New password: #{new_password}"
    puts "   Updated at: #{Time.now.utc}"
    
    # Verify the update
    verify_result = conn.exec_params(
      "SELECT encrypted_password FROM users WHERE id = $1",
      [user_id]
    )
    
    updated_hash = verify_result[0]['encrypted_password']
    puts "\n🔍 Verification:"
    puts "   Password hash updated: #{updated_hash != old_password_hash}"
    puts "   New hash matches: #{updated_hash == new_encrypted_password}"
    
    # Test the new password
    if BCrypt::Password.new(updated_hash) == new_password
      puts "   ✅ Password verification successful!"
    else
      puts "   ❌ Password verification failed!"
    end
    
  else
    puts "❌ Failed to update password - no rows affected"
    exit 1
  end
  
rescue PG::Error => e
  puts "❌ Database error: #{e.message}"
  exit 1
rescue => e
  puts "❌ Error: #{e.message}"
  puts "   #{e.backtrace.first}"
  exit 1
ensure
  conn&.close
  puts "\n🔌 Database connection closed"
end

puts "\n🎉 Password update completed successfully!"
puts "📧 Login credentials:"
puts "   Email: storeadmin@voicelinkai.com"
puts "   Password: password" 