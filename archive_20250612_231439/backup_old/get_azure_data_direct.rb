#!/usr/bin/env ruby

require 'pg'
require 'json'

puts "🚀 Getting Users, Inboxes, and Accounts from Azure Database..."
puts "=" * 70

# Database connection details
DB_HOST = 'chatwoot-db-fresh.postgres.database.azure.com'
DB_USER = 'chatwootuser'
DB_PASS = 'chatwoot123'
DB_NAME = 'chatwoot_production'
DB_PORT = 5432

def connect_to_database
  puts "🔌 Connecting to Azure PostgreSQL database..."
  puts "   Host: #{DB_HOST}"
  puts "   Database: #{DB_NAME}"
  puts "   User: #{DB_USER}"
  
  begin
    conn = PG.connect(
      host: DB_HOST,
      port: DB_PORT,
      dbname: DB_NAME,
      user: DB_USER,
      password: DB_PASS,
      sslmode: 'require'
    )
    puts "✅ Database connection successful!"
    return conn
  rescue PG::Error => e
    puts "❌ Database connection failed: #{e.message}"
    exit 1
  end
end

def execute_query(conn, query, description)
  puts "\n🔍 #{description}..."
  puts "   SQL: #{query}"
  
  begin
    result = conn.exec(query)
    puts "✅ Query successful - #{result.ntuples} rows returned"
    return result
  rescue PG::Error => e
    puts "❌ Query failed: #{e.message}"
    return nil
  end
end

def format_timestamp(timestamp)
  return 'N/A' if timestamp.nil?
  Time.parse(timestamp).strftime('%Y-%m-%d %H:%M:%S UTC') rescue timestamp
end

# Connect to database
conn = connect_to_database

puts "\n" + "=" * 70
puts "📊 ACCOUNTS"
puts "=" * 70

accounts_query = <<~SQL
  SELECT 
    id, 
    name, 
    status, 
    locale, 
    domain, 
    support_email,
    created_at,
    updated_at,
    (SELECT COUNT(*) FROM account_users WHERE account_id = accounts.id) as user_count,
    (SELECT COUNT(*) FROM inboxes WHERE account_id = accounts.id) as inbox_count
  FROM accounts 
  ORDER BY created_at DESC;
SQL

accounts_result = execute_query(conn, accounts_query, "Getting all accounts")

if accounts_result
  accounts_result.each_with_index do |row, index|
    puts "\n#{index + 1}. ACCOUNT: #{row['name']} (ID: #{row['id']})"
    puts "   Status: #{row['status'] || 'N/A'}"
    puts "   Locale: #{row['locale'] || 'N/A'}"
    puts "   Domain: #{row['domain'] || 'N/A'}"
    puts "   Support Email: #{row['support_email'] || 'N/A'}"
    puts "   Users: #{row['user_count']}"
    puts "   Inboxes: #{row['inbox_count']}"
    puts "   Created: #{format_timestamp(row['created_at'])}"
    puts "   Updated: #{format_timestamp(row['updated_at'])}"
  end
  
  # For each account, get detailed users and inboxes
  accounts_result.each do |account|
    account_id = account['id']
    account_name = account['name']
    
    puts "\n" + "=" * 50
    puts "🏢 DETAILED INFO FOR: #{account_name} (ID: #{account_id})"
    puts "=" * 50
    
    # Get users for this account
    puts "\n👥 USERS/AGENTS:"
    users_query = <<~SQL
      SELECT 
        u.id,
        u.name,
        u.email,
        u.type,
        u.availability,
        u.confirmed_at,
        u.created_at,
        u.updated_at,
        au.role as account_role
      FROM users u
      INNER JOIN account_users au ON u.id = au.user_id 
      WHERE au.account_id = #{account_id}
      ORDER BY u.created_at DESC;
    SQL
    
    users_result = execute_query(conn, users_query, "Getting users for account #{account_id}")
    
    if users_result && users_result.ntuples > 0
      users_result.each_with_index do |user, index|
        puts "  #{index + 1}. #{user['name'] || 'N/A'} (#{user['email'] || 'N/A'})"
        puts "     ID: #{user['id']}"
        puts "     Type: #{user['type'] || 'N/A'}"
        puts "     Role: #{user['account_role'] || 'N/A'}"
        puts "     Availability: #{user['availability'] || 'N/A'}"
        puts "     Confirmed: #{user['confirmed_at'] ? 'Yes' : 'No'}"
        puts "     Created: #{format_timestamp(user['created_at'])}"
        puts ""
      end
    else
      puts "  ❌ No users found for this account"
    end
    
    # Get inboxes for this account
    puts "\n📥 INBOXES:"
    inboxes_query = <<~SQL
      SELECT 
        i.id,
        i.name,
        i.channel_type,
        i.account_id,
        i.enable_auto_assignment,
        i.greeting_enabled,
        i.greeting_message,
        i.created_at,
        i.updated_at,
        (SELECT COUNT(*) FROM conversations WHERE inbox_id = i.id) as conversation_count
      FROM inboxes i
      WHERE i.account_id = #{account_id}
      ORDER BY i.created_at DESC;
    SQL
    
    inboxes_result = execute_query(conn, inboxes_query, "Getting inboxes for account #{account_id}")
    
    if inboxes_result && inboxes_result.ntuples > 0
      inboxes_result.each_with_index do |inbox, index|
        puts "  #{index + 1}. #{inbox['name'] || 'N/A'} (ID: #{inbox['id']})"
        puts "     Channel Type: #{inbox['channel_type'] || 'N/A'}"
        puts "     Auto Assignment: #{inbox['enable_auto_assignment'] ? 'Enabled' : 'Disabled'}"
        puts "     Greeting: #{inbox['greeting_enabled'] ? 'Enabled' : 'Disabled'}"
        puts "     Conversations: #{inbox['conversation_count']}"
        puts "     Created: #{format_timestamp(inbox['created_at'])}"
        puts ""
      end
    else
      puts "  ❌ No inboxes found for this account"
    end
  end
else
  puts "❌ No accounts found"
end

puts "\n" + "=" * 70
puts "📈 SYSTEM STATISTICS"
puts "=" * 70

# Get overall system statistics
stats_queries = {
  'Total Accounts' => 'SELECT COUNT(*) FROM accounts',
  'Total Users' => 'SELECT COUNT(*) FROM users',
  'Total Inboxes' => 'SELECT COUNT(*) FROM inboxes',
  'Total Conversations' => 'SELECT COUNT(*) FROM conversations',
  'Total Messages' => 'SELECT COUNT(*) FROM messages',
  'Active Users (last 30 days)' => "SELECT COUNT(*) FROM users WHERE updated_at > NOW() - INTERVAL '30 days'",
  'Recent Conversations (last 7 days)' => "SELECT COUNT(*) FROM conversations WHERE created_at > NOW() - INTERVAL '7 days'"
}

stats_queries.each do |description, query|
  result = execute_query(conn, query, description)
  if result && result.ntuples > 0
    count = result[0]['count']
    puts "📊 #{description}: #{count}"
  end
end

# Get platform apps and access tokens
puts "\n🔑 PLATFORM APPS & ACCESS TOKENS:"
platform_query = <<~SQL
  SELECT 
    pa.id,
    pa.name,
    pa.created_at,
    at.token,
    at.created_at as token_created_at
  FROM platform_apps pa
  LEFT JOIN access_tokens at ON pa.id = at.owner_id AND at.owner_type = 'PlatformApp'
  ORDER BY pa.created_at DESC;
SQL

platform_result = execute_query(conn, platform_query, "Getting platform apps and tokens")

if platform_result && platform_result.ntuples > 0
  platform_result.each_with_index do |app, index|
    puts "  #{index + 1}. #{app['name']} (ID: #{app['id']})"
    puts "     Token: #{app['token'] ? app['token'][0..20] + '...' : 'No token'}"
    puts "     App Created: #{format_timestamp(app['created_at'])}"
    puts "     Token Created: #{format_timestamp(app['token_created_at'])}"
    puts ""
  end
else
  puts "  ❌ No platform apps found"
end

# Close database connection
conn.close
puts "\n" + "=" * 70
puts "✨ Azure Environment Data Retrieval Complete!"
puts "=" * 70 