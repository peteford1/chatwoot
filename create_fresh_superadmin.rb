#!/usr/bin/env ruby

require 'pg'
require 'bcrypt'
require 'securerandom'

# Database connection
conn = PG.connect(
  host: 'chatwoot-db-fresh.postgres.database.azure.com',
  port: 5432,
  dbname: 'chatwoot_production',
  user: 'chatwootuser',
  password: 'chatwoot123'
)

begin
  # User details
  email = 'admin@voicelinkai.com'
  name = 'Super Admin'
  password = 'SuperAdmin123!'
  
  # Generate required fields
  password_hash = BCrypt::Password.create(password)
  uid = SecureRandom.uuid
  provider = 'email'
  
  puts "Creating SuperAdmin user..."
  puts "Email: #{email}"
  puts "Name: #{name}"
  puts "Password: #{password}"
  puts "UID: #{uid}"
  
  # Insert the user
  result = conn.exec_params(
    "INSERT INTO users (email, name, encrypted_password, uid, provider, type, confirmed_at, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW(), NOW()) RETURNING id",
    [email, name, password_hash, uid, provider, 'SuperAdmin']
  )
  
  if result.ntuples > 0
    user_id = result[0]['id']
    puts "\n✅ SuperAdmin user created successfully!"
    puts "User ID: #{user_id}"
    
    # Verify the user was created
    verify_result = conn.exec_params("SELECT id, email, name, type, confirmed_at FROM users WHERE id = $1", [user_id])
    
    if verify_result.ntuples > 0
      user = verify_result[0]
      puts "\nUser verification:"
      puts "ID: #{user['id']}"
      puts "Email: #{user['email']}"
      puts "Name: #{user['name']}"
      puts "Type: #{user['type']}"
      puts "Confirmed: #{user['confirmed_at']}"
      
      puts "\n🎉 SuperAdmin user is ready!"
      puts "You can now login at: https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/super_admin/sign_in"
      puts "Email: #{email}"
      puts "Password: #{password}"
    end
  else
    puts "\n❌ Failed to create user"
  end
  
rescue PG::Error => e
  puts "Database error: #{e.message}"
  puts "Error details: #{e.class}"
ensure
  conn.close if conn
end 