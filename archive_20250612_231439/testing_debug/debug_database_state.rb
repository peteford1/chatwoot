#!/usr/bin/env ruby

require 'pg'

# Database connection
conn = PG.connect(
  host: 'chatwoot-db-fresh.postgres.database.azure.com',
  port: 5432,
  dbname: 'chatwoot_production',
  user: 'chatwootuser',
  password: 'chatwoot123'
)

begin
  puts "=== DATABASE DEBUG INFORMATION ==="
  puts "Connected to: chatwoot-db-fresh.postgres.database.azure.com"
  puts "Database: chatwoot_production"
  puts "User: chatwootuser"
  puts
  
  # Check if users table exists
  table_check = conn.exec("SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users')")
  users_table_exists = table_check[0]['exists'] == 't'
  
  puts "Users table exists: #{users_table_exists}"
  
  if users_table_exists
    # Count users
    count_result = conn.exec("SELECT COUNT(*) as count FROM users")
    user_count = count_result[0]['count'].to_i
    
    puts "Total users in database: #{user_count}"
    
    if user_count > 0
      # Show all users
      result = conn.exec("SELECT id, email, name, type, confirmed_at, created_at, uid, provider FROM users ORDER BY id")
      
      puts "\n=== ALL USERS ==="
      result.each do |row|
        puts "ID: #{row['id']}"
        puts "Email: #{row['email']}"
        puts "Name: #{row['name']}"
        puts "Type: #{row['type']}"
        puts "UID: #{row['uid']}"
        puts "Provider: #{row['provider']}"
        puts "Confirmed: #{row['confirmed_at']}"
        puts "Created: #{row['created_at']}"
        puts "-" * 50
      end
    else
      puts "No users found in database."
    end
  else
    puts "Users table does not exist!"
  end
  
  # Check what tables do exist
  puts "\n=== ALL TABLES IN DATABASE ==="
  tables_result = conn.exec("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name")
  
  if tables_result.ntuples > 0
    puts "Found #{tables_result.ntuples} tables:"
    tables_result.each do |row|
      puts "- #{row['table_name']}"
    end
  else
    puts "No tables found in database!"
  end
  
  # Check database size and activity
  puts "\n=== DATABASE STATISTICS ==="
  stats_result = conn.exec("SELECT pg_size_pretty(pg_database_size('chatwoot_production')) as size")
  puts "Database size: #{stats_result[0]['size']}"
  
rescue PG::Error => e
  puts "Database error: #{e.message}"
  puts "Error class: #{e.class}"
ensure
  conn.close if conn
end 