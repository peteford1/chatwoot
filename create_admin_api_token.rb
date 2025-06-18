#!/usr/bin/env ruby

require 'pg'
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
  puts "Creating Admin API Token..."
  
  # Find the SuperAdmin user
  user_result = conn.exec("SELECT id, email, name FROM users WHERE type = 'SuperAdmin' LIMIT 1")
  
  if user_result.ntuples == 0
    puts "❌ No SuperAdmin user found!"
    exit 1
  end
  
  user = user_result[0]
  user_id = user['id']
  
  puts "Found SuperAdmin user:"
  puts "  ID: #{user_id}"
  puts "  Email: #{user['email']}"
  puts "  Name: #{user['name']}"
  puts
  
  # Generate a new API token
  token = SecureRandom.hex(12) # 24 character token
  
  # Insert the access token
  token_result = conn.exec_params(
    "INSERT INTO access_tokens (owner_id, owner_type, token, created_at, updated_at) VALUES ($1, $2, $3, NOW(), NOW()) RETURNING id, token",
    [user_id, 'User', token]
  )
  
  if token_result.ntuples > 0
    created_token = token_result[0]
    puts "✅ Admin API Token created successfully!"
    puts "Token ID: #{created_token['id']}"
    puts "Token: #{created_token['token']}"
    puts
    puts "🔧 Add this to your container environment variables:"
    puts "CHATWOOT_ADMIN_API_TOKEN=#{created_token['token']}"
    puts
    puts "📝 Test the token with:"
    puts "curl -H 'api_access_token: #{created_token['token']}' \\"
    puts "     https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/profile"
  else
    puts "❌ Failed to create API token"
  end
  
rescue PG::Error => e
  puts "Database error: #{e.message}"
ensure
  conn.close if conn
end 