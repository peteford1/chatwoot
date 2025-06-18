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
  # Check all users
  result = conn.exec("SELECT id, email, name, type, confirmed_at, created_at FROM users ORDER BY id")
  
  puts "Found #{result.ntuples} user(s):"
  puts "-" * 80
  
  result.each do |row|
    puts "ID: #{row['id']}"
    puts "Email: #{row['email']}"
    puts "Name: #{row['name']}"
    puts "Type: #{row['type']}"
    puts "Confirmed: #{row['confirmed_at']}"
    puts "Created: #{row['created_at']}"
    puts "-" * 40
  end
  
rescue PG::Error => e
  puts "Database error: #{e.message}"
ensure
  conn.close if conn
end 