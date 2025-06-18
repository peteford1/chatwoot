#!/usr/bin/env ruby

require 'pg'
require 'securerandom'
require 'json'

puts "=== VoiceLinkAI Direct Database Seeder ==="
puts "Connecting directly to database to create integration data..."

# Database connection parameters
DB_HOST = 'chatwoot-db-fresh.postgres.database.azure.com'
DB_NAME = 'chatwoot_shared'
DB_USER = 'chatwoot_test'
DB_PASSWORD = 'Chatwoot2024!'

begin
  # Connect to database
  conn = PG.connect(
    host: DB_HOST,
    dbname: DB_NAME,
    user: DB_USER,
    password: DB_PASSWORD,
    port: 5432,
    options: '-c search_path=test'
  )
  
  puts "✅ Connected to database successfully"
  
  # Check if tables exist
  tables_check = conn.exec("SELECT table_name FROM information_schema.tables WHERE table_schema = 'test' AND table_name IN ('platform_apps', 'accounts', 'users', 'account_users', 'access_tokens')")
  
  if tables_check.ntuples == 0
    puts "❌ Required tables not found in test schema. Database may not be properly set up."
    exit 1
  end
  
  puts "✅ Required tables found in test schema"
  
  # Generate tokens
  platform_token = SecureRandom.hex(32)
  admin_token = SecureRandom.hex(32)
  
  # 1. Create or find Platform App
  platform_app_result = conn.exec_params(
    "INSERT INTO platform_apps (name, created_at, updated_at) VALUES ($1, NOW(), NOW()) ON CONFLICT (name) DO UPDATE SET updated_at = NOW() RETURNING id",
    ['VoiceLinkAI test']
  )
  
  if platform_app_result.ntuples == 0
    # Platform app already exists, get its ID
    platform_app_result = conn.exec_params("SELECT id FROM platform_apps WHERE name = $1", ['VoiceLinkAI test'])
  end
  
  platform_app_id = platform_app_result[0]['id']
  puts "✅ Platform App ID: #{platform_app_id}"
  
  # 2. Create Platform App access token
  conn.exec_params(
    "INSERT INTO access_tokens (owner_type, owner_id, token, created_at, updated_at) VALUES ('PlatformApp', $1, $2, NOW(), NOW()) ON CONFLICT (owner_type, owner_id) DO UPDATE SET token = $2, updated_at = NOW()",
    [platform_app_id, platform_token]
  )
  
  # 3. Create or find Account
  account_result = conn.exec_params(
    "INSERT INTO accounts (name, locale, created_at, updated_at) VALUES ($1, 'en', NOW(), NOW()) ON CONFLICT (name) DO UPDATE SET updated_at = NOW() RETURNING id",
    ['voicelinkai-test']
  )
  
  if account_result.ntuples == 0
    # Account already exists, get its ID
    account_result = conn.exec_params("SELECT id FROM accounts WHERE name = $1", ['voicelinkai-test'])
  end
  
  account_id = account_result[0]['id']
  puts "✅ Account ID: #{account_id}"
  
  # 4. Create or find User
  user_email = 'admin@voicelinkai-test.com'
  user_result = conn.exec_params(
    "INSERT INTO users (name, email, password_digest, confirmed_at, created_at, updated_at) VALUES ($1, $2, $3, NOW(), NOW(), NOW()) ON CONFLICT (email) DO UPDATE SET updated_at = NOW() RETURNING id",
    ['VoiceLinkAI Admin', user_email, '$2a$12$dummy.hash.for.password.123321Qq']
  )
  
  if user_result.ntuples == 0
    # User already exists, get its ID
    user_result = conn.exec_params("SELECT id FROM users WHERE email = $1", [user_email])
  end
  
  user_id = user_result[0]['id']
  puts "✅ User ID: #{user_id}"
  
  # 5. Create User access token
  conn.exec_params(
    "INSERT INTO access_tokens (owner_type, owner_id, token, created_at, updated_at) VALUES ('User', $1, $2, NOW(), NOW()) ON CONFLICT (owner_type, owner_id) DO UPDATE SET token = $2, updated_at = NOW()",
    [user_id, admin_token]
  )
  
  # 6. Link User to Account
  conn.exec_params(
    "INSERT INTO account_users (account_id, user_id, role, created_at, updated_at) VALUES ($1, $2, 'administrator', NOW(), NOW()) ON CONFLICT (account_id, user_id) DO UPDATE SET role = 'administrator', updated_at = NOW()",
    [account_id, user_id]
  )
  
  puts "\n🎉 VoiceLinkAI Integration Setup Complete!"
  puts "=" * 50
  puts "PLATFORM TOKEN: #{platform_token}"
  puts "ADMIN TOKEN: #{admin_token}"
  puts "ACCOUNT ID: #{account_id}"
  puts "USER ID: #{user_id}"
  puts "=" * 50
  puts "\nTest URLs:"
  puts "Platform API: https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/platform/api/v1/accounts"
  puts "Application API: https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/profile"
  puts "\nUse these credentials for VoiceLinkAI integration!"
  
rescue PG::Error => e
  puts "❌ Database error: #{e.message}"
  exit 1
rescue => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.first(3)
  exit 1
ensure
  conn&.close
end 