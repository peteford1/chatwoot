#!/usr/bin/env ruby

require 'pg'
require 'securerandom'

puts "🚨 EMERGENCY TOKEN GENERATION - AZURE DATABASE"
puts "=" * 60

# Azure PostgreSQL connection details
DB_HOST = 'chatwoot-postgres-test.postgres.database.azure.com'
DB_NAME = 'chatwoot_production'
DB_USER = 'chatwoot'
DB_PASSWORD = ENV['AZURE_DB_PASSWORD'] || 'your_db_password_here'

def connect_to_database
  puts "🔌 Connecting to Azure PostgreSQL..."
  
  conn = PG.connect(
    host: DB_HOST,
    dbname: DB_NAME,
    user: DB_USER,
    password: DB_PASSWORD,
    port: 5432,
    sslmode: 'require'
  )
  
  puts "✅ Connected to database successfully"
  conn
rescue PG::Error => e
  puts "❌ Database connection failed: #{e.message}"
  puts "\n💡 Make sure to set AZURE_DB_PASSWORD environment variable:"
  puts "export AZURE_DB_PASSWORD='your_actual_password'"
  exit 1
end

def create_emergency_admin_user(conn)
  puts "\n👤 Creating emergency admin user..."
  
  # Generate unique credentials
  unique_id = SecureRandom.hex(4)
  email = "emergency_admin_#{unique_id}@chatwoot.local"
  password_digest = '$2a$11$' + SecureRandom.base64(60).tr('+/=', 'xyz')[0..59] # Fake bcrypt hash
  
  # Create user
  create_user_sql = <<~SQL
    INSERT INTO users (name, email, password_digest, confirmed_at, created_at, updated_at)
    VALUES ($1, $2, $3, NOW(), NOW(), NOW())
    RETURNING id, email
  SQL
  
  result = conn.exec_params(create_user_sql, [
    "Emergency Admin",
    email,
    password_digest
  ])
  
  user = result[0]
  user_id = user['id'].to_i
  
  puts "✅ Created emergency user: #{user['email']} (ID: #{user_id})"
  
  # Get first account ID
  account_result = conn.exec("SELECT id FROM accounts ORDER BY id LIMIT 1")
  if account_result.ntuples == 0
    puts "❌ No accounts found in database"
    return nil
  end
  
  account_id = account_result[0]['id'].to_i
  puts "📋 Using account ID: #{account_id}"
  
  # Create account_user relationship as administrator
  create_account_user_sql = <<~SQL
    INSERT INTO account_users (account_id, user_id, role, created_at, updated_at)
    VALUES ($1, $2, 'administrator', NOW(), NOW())
  SQL
  
  conn.exec_params(create_account_user_sql, [account_id, user_id])
  puts "✅ Added user to account as administrator"
  
  return { user_id: user_id, email: email, account_id: account_id }
end

def create_api_token(conn, user_id)
  puts "\n🔑 Creating API token for user..."
  
  api_token = SecureRandom.hex(32)
  
  create_token_sql = <<~SQL
    INSERT INTO access_tokens (owner_id, owner_type, token, created_at, updated_at)
    VALUES ($1, 'User', $2, NOW(), NOW())
    RETURNING token
  SQL
  
  result = conn.exec_params(create_token_sql, [user_id, api_token])
  token = result[0]['token']
  
  puts "✅ Created API token: #{token}"
  return token
end

def create_platform_app_token(conn, account_id)
  puts "\n🏢 Creating platform app and token..."
  
  # Create platform app
  app_name = "Emergency Platform App - #{Time.now.strftime('%Y%m%d_%H%M%S')}"
  
  create_app_sql = <<~SQL
    INSERT INTO platform_apps (name, created_at, updated_at)
    VALUES ($1, NOW(), NOW())
    RETURNING id, name
  SQL
  
  app_result = conn.exec_params(create_app_sql, [app_name])
  app = app_result[0]
  app_id = app['id'].to_i
  
  puts "✅ Created platform app: #{app['name']} (ID: #{app_id})"
  
  # Create platform app permissible (link to account)
  create_permissible_sql = <<~SQL
    INSERT INTO platform_app_permissibles (platform_app_id, permissible_type, permissible_id, created_at, updated_at)
    VALUES ($1, 'Account', $2, NOW(), NOW())
  SQL
  
  conn.exec_params(create_permissible_sql, [app_id, account_id])
  puts "✅ Linked platform app to account"
  
  # Create access token for platform app
  platform_token = SecureRandom.hex(32)
  
  create_platform_token_sql = <<~SQL
    INSERT INTO access_tokens (owner_id, owner_type, token, created_at, updated_at)
    VALUES ($1, 'PlatformApp', $2, NOW(), NOW())
    RETURNING token
  SQL
  
  token_result = conn.exec_params(create_platform_token_sql, [app_id, platform_token])
  token = token_result[0]['token']
  
  puts "✅ Created platform token: #{token}"
  return token
end

def test_tokens(user_token, platform_token)
  puts "\n🧪 Testing generated tokens..."
  
  require 'net/http'
  require 'json'
  require 'uri'
  
  base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
  
  # Test user token
  puts "\n📱 Testing user token..."
  uri = URI("#{base_url}/api/v1/profile")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  
  request = Net::HTTP::Get.new(uri)
  request['api_access_token'] = user_token
  
  begin
    response = http.request(request)
    if response.code.to_i < 400
      puts "✅ User token works! Status: #{response.code}"
    else
      puts "❌ User token failed: #{response.code} - #{response.body[0..100]}"
    end
  rescue => e
    puts "❌ User token test error: #{e.message}"
  end
  
  # Test platform token
  puts "\n🏢 Testing platform token..."
  uri = URI("#{base_url}/platform/api/v1/accounts")
  request = Net::HTTP::Get.new(uri)
  request['api_access_token'] = platform_token
  
  begin
    response = http.request(request)
    if response.code.to_i < 400
      puts "✅ Platform token works! Status: #{response.code}"
    else
      puts "❌ Platform token failed: #{response.code} - #{response.body[0..100]}"
    end
  rescue => e
    puts "❌ Platform token test error: #{e.message}"
  end
end

# Main execution
begin
  conn = connect_to_database
  
  user_info = create_emergency_admin_user(conn)
  if user_info.nil?
    puts "❌ Failed to create emergency user"
    exit 1
  end
  
  user_token = create_api_token(conn, user_info[:user_id])
  platform_token = create_platform_app_token(conn, user_info[:account_id])
  
  puts "\n" + "=" * 60
  puts "🎉 EMERGENCY TOKENS CREATED SUCCESSFULLY!"
  puts "=" * 60
  puts "User Email: #{user_info[:email]}"
  puts "User Token: #{user_token}"
  puts "Platform Token: #{platform_token}"
  puts "=" * 60
  
  puts "\n💾 Save these tokens securely:"
  puts "export CHATWOOT_USER_TOKEN='#{user_token}'"
  puts "export CHATWOOT_PLATFORM_TOKEN='#{platform_token}'"
  
  test_tokens(user_token, platform_token)
  
ensure
  conn&.close
  puts "\n🔌 Database connection closed"
end 