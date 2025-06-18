#!/usr/bin/env ruby

# Script to update storeadmin@voicelinkai.com password
# Created: 2025-01-06 20:37:00 UTC
# Reason: User requested password reset to 'password'

require 'bundler/setup'
require 'rails/all'
require 'bcrypt'

# Load Rails environment
ENV['RAILS_ENV'] ||= 'production'
require_relative 'config/environment'

begin
  puts "🔍 Looking for user: storeadmin@voicelinkai.com"
  
  user = User.find_by(email: 'storeadmin@voicelinkai.com')
  
  if user.nil?
    puts "❌ User not found: storeadmin@voicelinkai.com"
    exit 1
  end
  
  puts "✅ Found user: #{user.email}"
  puts "   Current user ID: #{user.id}"
  puts "   Current name: #{user.name}"
  puts "   Current role: #{user.type}"
  
  # Store old password hash for backup record
  old_password_hash = user.encrypted_password
  puts "   Old password hash: #{old_password_hash[0..20]}..." # Show first 20 chars only
  
  # Generate new encrypted password using Devise's method
  new_password = 'password'
  new_encrypted_password = Devise::Encryptor.digest(User, new_password)
  
  puts "\n🔐 Generating new encrypted password..."
  puts "   New password hash: #{new_encrypted_password[0..20]}..." # Show first 20 chars only
  
  # Update the password
  puts "\n💾 Updating password in database..."
  
  user.update_column(:encrypted_password, new_encrypted_password)
  
  puts "✅ Password updated successfully!"
  puts "   Email: storeadmin@voicelinkai.com"
  puts "   New password: password"
  puts "   Updated at: #{Time.current}"
  
  # Verify the update
  user.reload
  puts "\n🔍 Verification:"
  puts "   Password hash changed: #{user.encrypted_password != old_password_hash}"
  puts "   Can authenticate: #{user.valid_password?(new_password)}"
  
  puts "\n📋 BACKUP INFO (for rollback if needed):"
  puts "   User ID: #{user.id}"
  puts "   Email: #{user.email}"
  puts "   Old password hash: #{old_password_hash}"
  puts "   Change timestamp: #{Time.current}"
  
rescue => e
  puts "❌ Error updating password: #{e.message}"
  puts "   #{e.backtrace.first}"
  exit 1
end 