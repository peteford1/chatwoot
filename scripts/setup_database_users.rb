#!/usr/bin/env ruby

require 'pg'

puts "🔐 Setting up Database Users for Environment Isolation"
puts "=" * 60

# Database connection details
DB_HOST = "chatwoot-db-fresh.postgres.database.azure.com"
DB_PORT = 5432
ADMIN_USER = "chatwoot"
ADMIN_PASSWORD = "Fme82skjLO!"

# Environment-specific database users
USERS = {
  development: {
    username: "chatwoot_dev",
    password: "DevSecure2025!",
    database: "chatwoot_shared",
    schema: "development"
  },
  test: {
    username: "chatwoot_test", 
    password: "TestSecure2025!",
    database: "chatwoot_shared",
    schema: "test"
  },
  staging: {
    username: "chatwoot_staging",
    password: "StagingSecure2025!",
    database: "chatwoot_shared", 
    schema: "staging"
  },
  production: {
    username: "chatwoot_prod",
    password: "ProdSecure2025!",
    database: "chatwoot_production",
    schema: "public"
  }
}

def execute_sql(connection, sql, description)
  puts "📋 #{description}..."
  begin
    connection.exec(sql)
    puts "✅ Success: #{description}"
  rescue PG::Error => e
    if e.message.include?("already exists")
      puts "ℹ️  Skipped: #{description} (already exists)"
    else
      puts "❌ Error: #{description} - #{e.message}"
    end
  end
end

# Connect to each database and set up users
USERS.each do |env, config|
  puts "\n🔧 Setting up #{env.upcase} environment user..."
  puts "Database: #{config[:database]}, Schema: #{config[:schema]}"
  
  begin
    # Connect to the specific database
    conn = PG.connect(
      host: DB_HOST,
      port: DB_PORT,
      dbname: config[:database],
      user: ADMIN_USER,
      password: ADMIN_PASSWORD,
      sslmode: 'require'
    )
    
    # Create schema if it doesn't exist
    execute_sql(conn, 
      "CREATE SCHEMA IF NOT EXISTS #{config[:schema]};",
      "Creating schema #{config[:schema]}"
    )
    
    # Create user if it doesn't exist
    execute_sql(conn, 
      "CREATE USER #{config[:username]} WITH PASSWORD '#{config[:password]}';",
      "Creating user #{config[:username]}"
    )
    
    # Grant schema permissions
    execute_sql(conn, 
      "GRANT USAGE ON SCHEMA #{config[:schema]} TO #{config[:username]};",
      "Granting USAGE on schema #{config[:schema]}"
    )
    
    execute_sql(conn, 
      "GRANT CREATE ON SCHEMA #{config[:schema]} TO #{config[:username]};",
      "Granting CREATE on schema #{config[:schema]}"
    )
    
    # Grant table permissions (for existing and future tables)
    execute_sql(conn, 
      "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA #{config[:schema]} TO #{config[:username]};",
      "Granting ALL on existing tables in #{config[:schema]}"
    )
    
    execute_sql(conn, 
      "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA #{config[:schema]} TO #{config[:username]};",
      "Granting ALL on existing sequences in #{config[:schema]}"
    )
    
    execute_sql(conn, 
      "ALTER DEFAULT PRIVILEGES IN SCHEMA #{config[:schema]} GRANT ALL ON TABLES TO #{config[:username]};",
      "Setting default privileges for future tables"
    )
    
    execute_sql(conn, 
      "ALTER DEFAULT PRIVILEGES IN SCHEMA #{config[:schema]} GRANT ALL ON SEQUENCES TO #{config[:username]};",
      "Setting default privileges for future sequences"
    )
    
    # Set default search path for the user
    execute_sql(conn, 
      "ALTER USER #{config[:username]} SET search_path TO #{config[:schema]};",
      "Setting default search_path for #{config[:username]}"
    )
    
    puts "✅ #{env.upcase} user setup complete!"
    
  rescue PG::Error => e
    puts "❌ Failed to connect to #{config[:database]}: #{e.message}"
  ensure
    conn&.close
  end
end

puts "\n🎯 DATABASE USER SUMMARY:"
puts "=" * 60

USERS.each do |env, config|
  puts "#{env.upcase}:"
  puts "  User: #{config[:username]}"
  puts "  Password: #{config[:password]}"
  puts "  Database: #{config[:database]}"
  puts "  Schema: #{config[:schema]}"
  puts "  Connection: postgresql://#{config[:username]}:#{config[:password]}@#{DB_HOST}:#{DB_PORT}/#{config[:database]}?options=-csearch_path%3D#{config[:schema]}"
  puts ""
end

puts "🔐 SECURITY BENEFITS:"
puts "- Each environment has its own database user"
puts "- Users can only access their assigned schema"
puts "- Prevents accidental cross-environment data access"
puts "- Enables environment-specific permission auditing"
puts ""

puts "📝 NEXT STEPS:"
puts "1. Update environment variables with new user credentials"
puts "2. Test connections for each environment"
puts "3. Run database migrations for each schema"
puts "4. Update deployment configurations" 