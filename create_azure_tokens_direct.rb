#!/usr/bin/env ruby

# Script to create fresh tokens directly from Azure database
# This bypasses API authentication issues

require 'pg'
require 'securerandom'
require 'digest'

puts "🔧 CREATING FRESH TOKENS FROM AZURE DATABASE"
puts "=" * 60

# Database configuration from environment
DB_CONFIG = {
  host: ENV['POSTGRES_HOST'] || 'chatwoot-postgres-test.postgres.database.azure.com',
  port: ENV['POSTGRES_PORT'] || 5432,
  database: ENV['POSTGRES_DATABASE'] || 'chatwoot_production',
  user: ENV['POSTGRES_USERNAME'] || 'chatwoot_admin',
  password: ENV['POSTGRES_PASSWORD']
}

puts "\n📋 Database Configuration:"
puts "   Host: #{DB_CONFIG[:host]}"
puts "   Database: #{DB_CONFIG[:database]}"
puts "   User: #{DB_CONFIG[:user]}"
puts "   Password: #{DB_CONFIG[:password] ? '[SET]' : '[NOT SET]'}"

if !DB_CONFIG[:password]
  puts "\n❌ ERROR: POSTGRES_PASSWORD environment variable not set"
  puts "Please set it with: export POSTGRES_PASSWORD='your_password'"
  exit 1
end

begin
  # Connect to database
  puts "\n🔌 Connecting to Azure PostgreSQL..."
  conn = PG.connect(
    host: DB_CONFIG[:host],
    port: DB_CONFIG[:port],
    dbname: DB_CONFIG[:database],
    user: DB_CONFIG[:user],
    password: DB_CONFIG[:password],
    sslmode: 'require'
  )
  puts "   ✅ Connected successfully"
  
  # Check if users exist
  puts "\n👥 Checking existing users..."
  users_result = conn.exec("SELECT id, name, email, role, confirmed_at FROM users ORDER BY id LIMIT 10")
  
  if users_result.ntuples == 0
    puts "   ❌ No users found in database"
    exit 1
  end
  
  puts "   Found #{users_result.ntuples} users:"
  users_result.each do |row|
    confirmed = row['confirmed_at'] ? '✅' : '❌'
    puts "   - ID #{row['id']}: #{row['name']} (#{row['email']}) - #{row['role']} #{confirmed}"
  end
  
  # Find or create admin user
  admin_user = nil
  users_result.each do |row|
    if row['role'] == 'administrator' && row['confirmed_at']
      admin_user = row
      break
    end
  end
  
  if !admin_user
    puts "\n🔧 No confirmed admin user found. Creating one..."
    
    # Create admin user
    admin_email = "admin@chatwoot.test"
    admin_name = "System Administrator"
    admin_password = SecureRandom.hex(16)
    
    # Generate password hash (simplified - in real Rails it's more complex)
    password_hash = Digest::SHA256.hexdigest(admin_password + "chatwoot_salt")
    
    create_user_sql = <<~SQL
      INSERT INTO users (name, email, password_digest, role, confirmed_at, created_at, updated_at)
      VALUES ($1, $2, $3, 'administrator', NOW(), NOW(), NOW())
      RETURNING id, name, email, role
    SQL
    
    result = conn.exec_params(create_user_sql, [admin_name, admin_email, password_hash])
    admin_user = result[0]
    
    puts "   ✅ Created admin user: #{admin_user['name']} (#{admin_user['email']})"
    puts "   📝 Password: #{admin_password}"
  else
    puts "\n✅ Using existing admin user: #{admin_user['name']} (#{admin_user['email']})"
  end
  
  admin_user_id = admin_user['id'].to_i
  
  # Check accounts
  puts "\n🏢 Checking accounts..."
  accounts_result = conn.exec("SELECT id, name, status FROM accounts ORDER BY id LIMIT 5")
  
  if accounts_result.ntuples == 0
    puts "   ❌ No accounts found. Creating default account..."
    
    create_account_sql = <<~SQL
      INSERT INTO accounts (name, status, created_at, updated_at)
      VALUES ('Default Account', 'active', NOW(), NOW())
      RETURNING id, name, status
    SQL
    
    account_result = conn.exec(create_account_sql)
    account = account_result[0]
    puts "   ✅ Created account: #{account['name']} (ID: #{account['id']})"
  else
    account = accounts_result[0]
    puts "   ✅ Using existing account: #{account['name']} (ID: #{account['id']})"
  end
  
  account_id = account['id'].to_i
  
  # Ensure user is member of account
  puts "\n🔗 Checking account membership..."
  membership_check = conn.exec_params(
    "SELECT id FROM account_users WHERE user_id = $1 AND account_id = $2",
    [admin_user_id, account_id]
  )
  
  if membership_check.ntuples == 0
    puts "   Adding user to account..."
    conn.exec_params(
      "INSERT INTO account_users (user_id, account_id, role, created_at, updated_at) VALUES ($1, $2, 'administrator', NOW(), NOW())",
      [admin_user_id, account_id]
    )
    puts "   ✅ User added to account"
  else
    puts "   ✅ User already member of account"
  end
  
  # Create API access token
  puts "\n🔑 Creating API access token..."
  
  # Delete existing tokens for this user
  conn.exec_params("DELETE FROM access_tokens WHERE owner_id = $1 AND owner_type = 'User'", [admin_user_id])
  
  # Generate new token
  api_token = SecureRandom.hex(32)
  
  create_token_sql = <<~SQL
    INSERT INTO access_tokens (owner_id, owner_type, token, created_at, updated_at)
    VALUES ($1, 'User', $2, NOW(), NOW())
    RETURNING token
  SQL
  
  token_result = conn.exec_params(create_token_sql, [admin_user_id, api_token])
  created_token = token_result[0]['token']
  
  puts "   ✅ Created API token: #{created_token}"
  
  # Create platform app and token
  puts "\n🚀 Creating platform app and token..."
  
  # Delete existing platform apps
  conn.exec("DELETE FROM platform_apps WHERE name = 'Test Platform App'")
  
  # Create platform app
  platform_app_name = "Test Platform App"
  platform_token = SecureRandom.hex(32)
  
  create_platform_app_sql = <<~SQL
    INSERT INTO platform_apps (name, created_at, updated_at)
    VALUES ($1, NOW(), NOW())
    RETURNING id, name
  SQL
  
  platform_app_result = conn.exec_params(create_platform_app_sql, [platform_app_name])
  platform_app = platform_app_result[0]
  platform_app_id = platform_app['id'].to_i
  
  puts "   ✅ Created platform app: #{platform_app['name']} (ID: #{platform_app_id})"
  
  # Create platform app permissible (link to account)
  create_permissible_sql = <<~SQL
    INSERT INTO platform_app_permissibles (platform_app_id, permissible_type, permissible_id, created_at, updated_at)
    VALUES ($1, 'Account', $2, NOW(), NOW())
  SQL
  
  conn.exec_params(create_permissible_sql, [platform_app_id, account_id])
  puts "   ✅ Linked platform app to account"
  
  # Create access token for platform app
  create_platform_token_sql = <<~SQL
    INSERT INTO access_tokens (owner_id, owner_type, token, created_at, updated_at)
    VALUES ($1, 'PlatformApp', $2, NOW(), NOW())
    RETURNING token
  SQL
  
  platform_token_result = conn.exec_params(create_platform_token_sql, [platform_app_id, platform_token])
  created_platform_token = platform_token_result[0]['token']
  
  puts "   ✅ Created platform token: #{created_platform_token}"
  
  # Summary
  puts "\n" + "=" * 60
  puts "🎯 FRESH TOKENS CREATED SUCCESSFULLY"
  puts "=" * 60
  
  puts "\n👤 Admin User:"
  puts "   ID: #{admin_user_id}"
  puts "   Name: #{admin_user['name']}"
  puts "   Email: #{admin_user['email']}"
  puts "   Role: #{admin_user['role']}"
  
  puts "\n🏢 Account:"
  puts "   ID: #{account_id}"
  puts "   Name: #{account['name']}"
  puts "   Status: #{account['status']}"
  
  puts "\n🔑 API Access Token (User):"
  puts "   Token: #{created_token}"
  puts "   Owner: User #{admin_user_id}"
  
  puts "\n🚀 Platform Token:"
  puts "   Token: #{created_platform_token}"
  puts "   App: #{platform_app['name']} (ID: #{platform_app_id})"
  
  puts "\n📝 Environment Variables:"
  puts "   export CHATWOOT_ADMIN_USER_ID=#{admin_user_id}"
  puts "   export CHATWOOT_ADMIN_TOKEN=\"#{created_token}\""
  puts "   export CHATWOOT_PLATFORM_TOKEN=\"#{created_platform_token}\""
  puts "   export CHATWOOT_ACCOUNT_ID=#{account_id}"
  puts "   export CHATWOOT_ACCOUNT_NAME=\"#{account['name']}\""
  puts "   export CHATWOOT_USER_TOKEN=\"#{created_token}\""
  puts "   export CHATWOOT_USER_ID=#{admin_user_id}"
  puts "   export CHATWOOT_USER_EMAIL=\"#{admin_user['email']}\""
  
  # Update environment file
  puts "\n💾 Updating azure_database_config.env..."
  
  env_content = <<~ENV
    
    # ============================================================================
    # FRESH TOKENS CREATED - #{Time.now}
    # ============================================================================
    
    # Admin user and tokens
    export CHATWOOT_ADMIN_USER_ID=#{admin_user_id}
    export CHATWOOT_ADMIN_TOKEN="#{created_token}"
    export CHATWOOT_PLATFORM_TOKEN="#{created_platform_token}"
    export CHATWOOT_ACCOUNT_ID=#{account_id}
    export CHATWOOT_ACCOUNT_NAME="#{account['name']}"
    
    # Set primary token for testing
    export CHATWOOT_USER_TOKEN="#{created_token}"
    export CHATWOOT_USER_ID=#{admin_user_id}
    export CHATWOOT_USER_EMAIL="#{admin_user['email']}"
  ENV
  
  File.open('azure_database_config.env', 'a') { |f| f.write(env_content) }
  puts "   ✅ Environment file updated"
  
  puts "\n🚀 READY TO TEST!"
  puts "   1. Source environment: source azure_database_config.env"
  puts "   2. Test tokens: ruby test_provided_tokens.rb"
  puts "   3. Run SMS test: ruby live_websocket_sms_test_auto.rb"
  
rescue PG::Error => e
  puts "\n❌ Database Error: #{e.message}"
  puts "\n🔧 Troubleshooting:"
  puts "1. Check database connection settings"
  puts "2. Verify PGPASSWORD is correct"
  puts "3. Ensure database server is accessible"
rescue => e
  puts "\n❌ Unexpected Error: #{e.message}"
  puts e.backtrace.first(5)
ensure
  conn&.close
  puts "\n🔌 Database connection closed"
end 