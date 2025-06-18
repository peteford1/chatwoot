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
  # New password
  new_password = 'SuperAdmin123!'
  
  # Generate bcrypt hash
  password_hash = BCrypt::Password.create(new_password)
  
  puts "Generated password hash: #{password_hash}"
  
  # Update the user's password
  result = conn.exec_params(
    "UPDATE users SET encrypted_password = $1, confirmed_at = NOW(), confirmation_token = NULL WHERE email = 'admin@voicelinkai.com'",
    [password_hash]
  )
  
  puts "Updated #{result.cmd_tuples} user(s)"
  
  # Verify the user exists and get details
  user_result = conn.exec("SELECT id, email, type, confirmed_at, encrypted_password FROM users WHERE email = 'admin@voicelinkai.com'")
  
  if user_result.ntuples > 0
    user = user_result[0]
    puts "\nUser found:"
    puts "ID: #{user['id']}"
    puts "Email: #{user['email']}"
    puts "Type: #{user['type']}"
    puts "Confirmed: #{user['confirmed_at']}"
    puts "Password hash starts with: #{user['encrypted_password'][0..20]}..."
    
    # Test password verification
    stored_hash = BCrypt::Password.new(user['encrypted_password'])
    if stored_hash == new_password
      puts "\n✅ Password verification successful!"
    else
      puts "\n❌ Password verification failed!"
    end
  else
    puts "\n❌ User not found!"
  end
  
rescue PG::Error => e
  puts "Database error: #{e.message}"
ensure
  conn.close if conn
end 