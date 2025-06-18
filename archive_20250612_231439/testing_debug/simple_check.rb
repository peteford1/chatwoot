#!/usr/bin/env ruby

require 'pg'

# Database connection details
DB_HOST = 'chatwoot-db-fresh.postgres.database.azure.com'
DB_NAME = 'chatwoot_production'
DB_USER = 'chatwootuser'
DB_PASSWORD = 'chatwoot123'

begin
  puts "🔍 Connecting to Chatwoot database..."
  
  # Connect to PostgreSQL
  conn = PG.connect(
    host: DB_HOST,
    dbname: DB_NAME,
    user: DB_USER,
    password: DB_PASSWORD,
    port: 5432,
    sslmode: 'require'
  )
  
  puts "✅ Connected to database successfully!"
  
  # Get all accounts
  puts "\n📋 ACCOUNTS:"
  puts "=" * 50
  accounts_result = conn.exec("SELECT id, name, locale, status FROM accounts ORDER BY id")
  accounts_result.each do |row|
    puts "  Account ID: #{row['id']}"
    puts "  Name: #{row['name']}"
    puts "  Locale: #{row['locale']}"
    puts "  Status: #{row['status']}"
    puts "  " + "-" * 30
  end
  
  # Get all users
  puts "\n👥 USERS:"
  puts "=" * 50
  users_result = conn.exec("SELECT id, name, email, created_at FROM users ORDER BY id")
  users_result.each do |row|
    puts "  User ID: #{row['id']}"
    puts "  Name: #{row['name']}"
    puts "  Email: #{row['email']}"
    puts "  Created: #{row['created_at']}"
    puts "  " + "-" * 30
  end
  
  # Get account-user relationships
  puts "\n🔗 ACCOUNT-USER RELATIONSHIPS:"
  puts "=" * 50
  relationships_result = conn.exec("""
    SELECT 
      au.account_id,
      au.user_id,
      au.role,
      a.name as account_name,
      u.name as user_name,
      u.email as user_email
    FROM account_users au
    JOIN accounts a ON au.account_id = a.id
    JOIN users u ON au.user_id = u.id
    ORDER BY au.account_id, au.user_id
  """)
  
  relationships_result.each do |row|
    puts "  Account ID: #{row['account_id']} (#{row['account_name']})"
    puts "  User ID: #{row['user_id']} (#{row['user_name']} - #{row['user_email']})"
    puts "  Role: #{row['role']}"
    puts "  " + "-" * 30
  end
  
  # Get access tokens
  puts "\n🔑 ACCESS TOKENS:"
  puts "=" * 50
  tokens_result = conn.exec("""
    SELECT 
      at.id,
      at.token,
      at.owner_id,
      at.owner_type,
      u.name as user_name,
      u.email as user_email
    FROM access_tokens at
    LEFT JOIN users u ON at.owner_id = u.id AND at.owner_type = 'User'
    ORDER BY at.id
  """)
  
  tokens_result.each do |row|
    puts "  Token ID: #{row['id']}"
    puts "  Owner: #{row['user_name']} (#{row['user_email']})" if row['user_name']
    puts "  Owner ID: #{row['owner_id']} (#{row['owner_type']})"
    puts "  Token: #{row['token']}"
    puts "  " + "-" * 30
  end
  
rescue PG::Error => e
  puts "❌ Database error: #{e.message}"
rescue StandardError => e
  puts "❌ Error: #{e.message}"
ensure
  conn&.close
  puts "\n✅ Database connection closed."
end 