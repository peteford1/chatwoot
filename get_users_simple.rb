#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

puts "🚀 Getting Active Users from Chatwoot..."

# Database connection details
DB_HOST = 'chatwoot-db-new.postgres.database.azure.com'
DB_USER = 'chatwootuser'
DB_PASS = 'chatwoot123'
DB_NAME = 'chatwoot_production'

# API base URL
API_BASE = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'

puts "📊 Attempting to get user information..."

# Try to get user information via direct database query using psql
puts "\n🔍 Method 1: Direct Database Query"
db_command = "psql \"postgresql://#{DB_USER}:#{DB_PASS}@#{DB_HOST}:5432/#{DB_NAME}\" -c \"SELECT id, name, email, type, availability, created_at FROM users WHERE type IS NOT NULL ORDER BY created_at DESC LIMIT 20;\" -t"

puts "Executing: #{db_command.gsub(DB_PASS, '***')}"
db_result = `#{db_command} 2>&1`

if $?.success?
  puts "✅ Database query successful:"
  puts db_result
else
  puts "❌ Database query failed: #{db_result}"
end

# Try to get information via API calls
puts "\n🔍 Method 2: API Calls (without authentication - will likely fail)"

# Try different API endpoints
endpoints = [
  '/api/v1/profile',
  '/api/v1/accounts',
  '/super_admin/users',
  '/platform/api/v1/users'
]

endpoints.each do |endpoint|
  url = "#{API_BASE}#{endpoint}"
  puts "\n📡 Testing: #{url}"
  
  begin
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 10
    
    request = Net::HTTP::Get.new(uri)
    request['Content-Type'] = 'application/json'
    
    response = http.request(request)
    puts "📊 Response Code: #{response.code}"
    puts "📄 Response: #{response.body[0..200]}#{'...' if response.body.length > 200}"
    
  rescue => e
    puts "❌ Error: #{e.message}"
  end
end

puts "\n🔍 Method 3: Try to access SuperAdmin interface"
super_admin_url = "#{API_BASE}/super_admin"
puts "📡 Testing: #{super_admin_url}"

begin
  uri = URI(super_admin_url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  
  request = Net::HTTP::Get.new(uri)
  response = http.request(request)
  
  puts "📊 Response Code: #{response.code}"
  puts "📄 Response Headers: #{response.to_hash.inspect}"
  
rescue => e
  puts "❌ Error: #{e.message}"
end

puts "\n✨ User information gathering completed!"
puts "\n💡 To get authenticated access, you'll need to:"
puts "   1. Create a SuperAdmin user account"
puts "   2. Create a Platform App with access token"
puts "   3. Use the access token in API calls" 