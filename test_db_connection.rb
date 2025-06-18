#!/usr/bin/env ruby

require 'pg'

puts "🔍 TESTING AZURE DATABASE CONNECTION"
puts "=" * 50

# Database configuration from environment
host = ENV['POSTGRES_HOST'] || 'chatwoot-postgres-test.postgres.database.azure.com'
port = ENV['POSTGRES_PORT'] || 5432
database = ENV['POSTGRES_DATABASE'] || 'chatwoot_production'
user = ENV['POSTGRES_USERNAME'] || 'chatwoot_admin'
password = ENV['POSTGRES_PASSWORD']

puts "\n📋 Connection Details:"
puts "   Host: #{host}"
puts "   Port: #{port}"
puts "   Database: #{database}"
puts "   User: #{user}"
puts "   Password: #{password ? '[SET]' : '[NOT SET]'}"

if !password
  puts "\n❌ ERROR: POSTGRES_PASSWORD not set"
  exit 1
end

begin
  puts "\n🔌 Attempting connection..."
  
  # Try different connection methods
  connection_methods = [
    {
      name: "Standard connection",
      params: {
        host: host,
        port: port,
        dbname: database,
        user: user,
        password: password,
        sslmode: 'require'
      }
    },
    {
      name: "Connection string",
      params: "postgresql://#{user}:#{password}@#{host}:#{port}/#{database}?sslmode=require"
    }
  ]
  
  connection_methods.each do |method|
    puts "\n🧪 Trying #{method[:name]}..."
    
    begin
      if method[:params].is_a?(String)
        conn = PG.connect(method[:params])
      else
        conn = PG.connect(method[:params])
      end
      
      puts "   ✅ SUCCESS - Connected!"
      
      # Test basic query
      result = conn.exec("SELECT version(), current_database(), current_user")
      puts "   Database: #{result[0]['current_database']}"
      puts "   User: #{result[0]['current_user']}"
      puts "   Version: #{result[0]['version'].split(' ')[0..2].join(' ')}"
      
      # Check for Chatwoot tables
      tables_result = conn.exec("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('users', 'accounts', 'access_tokens') ORDER BY table_name")
      
      if tables_result.ntuples > 0
        puts "   ✅ Chatwoot tables found:"
        tables_result.each { |row| puts "      - #{row['table_name']}" }
      else
        puts "   ⚠️  No Chatwoot tables found"
      end
      
      conn.close
      puts "\n🎯 CONNECTION SUCCESSFUL - Ready to create tokens!"
      exit 0
      
    rescue PG::Error => e
      puts "   ❌ FAILED - #{e.message}"
    rescue => e
      puts "   ❌ FAILED - #{e.class}: #{e.message}"
    end
  end
  
  puts "\n❌ All connection methods failed"
  
rescue => e
  puts "\n❌ Unexpected error: #{e.message}"
  puts e.backtrace.first(3)
end 