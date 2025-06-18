#!/usr/bin/env ruby

require 'pg'
require 'bcrypt'

# Database connection
conn = PG.connect(
  host: 'chatwoot-db-fresh.postgres.database.azure.com',
  port: 5432,
  dbname: 'chatwoot_production',
  user: 'chatwootuser',
  password: 'chatwoot123'
)

begin
  email = 'admin@voicelinkai.com'
  test_password = 'SuperAdmin123!'
  
  puts "Testing login credentials for: #{email}"
  puts "Password: #{test_password}"
  puts
  
  # Get user from database
  result = conn.exec_params("SELECT id, email, name, type, encrypted_password, confirmed_at FROM users WHERE email = $1", [email])
  
  if result.ntuples > 0
    user = result[0]
    puts "✅ User found in database:"
    puts "  ID: #{user['id']}"
    puts "  Email: #{user['email']}"
    puts "  Name: #{user['name']}"
    puts "  Type: #{user['type']}"
    puts "  Confirmed: #{user['confirmed_at']}"
    puts
    
    # Test password
    stored_hash = user['encrypted_password']
    puts "Stored password hash: #{stored_hash[0..30]}..."
    
    begin
      bcrypt_hash = BCrypt::Password.new(stored_hash)
      if bcrypt_hash == test_password
        puts "✅ Password verification SUCCESSFUL!"
        puts "The credentials should work for login."
      else
        puts "❌ Password verification FAILED!"
        puts "The password does not match the stored hash."
      end
    rescue => e
      puts "❌ Error verifying password: #{e.message}"
    end
    
    # Check if user is confirmed
    if user['confirmed_at']
      puts "✅ User account is confirmed"
    else
      puts "❌ User account is NOT confirmed"
    end
    
  else
    puts "❌ User not found in database!"
  end
  
rescue PG::Error => e
  puts "Database error: #{e.message}"
ensure
  conn.close if conn
end 