#!/usr/bin/env ruby

# Fix Test Environment Script
# This script addresses environment isolation issues

require 'net/http'
require 'json'
require 'uri'

puts "=== Fixing Test Environment Isolation Issues ==="

# First, let's try to trigger database migrations via API
BASE_URL = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'

def make_request(method, url, headers = {}, body = nil)
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true if uri.scheme == 'https'
  
  request = case method.upcase
  when 'GET'
    Net::HTTP::Get.new(uri)
  when 'POST'
    Net::HTTP::Post.new(uri)
  end
  
  headers.each { |key, value| request[key] = value }
  request.body = body.to_json if body
  request['Content-Type'] = 'application/json' if body
  
  response = http.request(request)
  puts "#{method} #{url} -> #{response.code}"
  
  begin
    parsed_body = JSON.parse(response.body) if response.body && !response.body.empty?
    { code: response.code.to_i, body: parsed_body, raw_body: response.body }
  rescue JSON::ParserError
    { code: response.code.to_i, body: nil, raw_body: response.body }
  end
end

begin
  puts "\n1. Checking current environment status..."
  health = make_request('GET', BASE_URL)
  
  if health[:code] == 200 && health[:body]
    puts "✅ Container is running"
    puts "Environment info: #{health[:body]}"
  else
    puts "❌ Container health check failed"
    exit 1
  end
  
  puts "\n2. Checking installation/migration status..."
  install_status = make_request('GET', "#{BASE_URL}/installation/onboarding")
  
  if install_status[:code] == 302
    puts "⚠️  Installation redirecting - likely already configured"
    puts "This suggests the test schema may need manual setup"
  end
  
  puts "\n3. Testing API endpoints..."
  
  # Test if any API endpoints work
  api_test = make_request('GET', "#{BASE_URL}/api/v1/profile")
  puts "Profile API: #{api_test[:code]} - #{api_test[:raw_body] && api_test[:raw_body][0..50]}"
  
  platform_test = make_request('GET', "#{BASE_URL}/platform/api/v1/accounts")
  puts "Platform API: #{platform_test[:code]} - #{platform_test[:raw_body] && platform_test[:raw_body][0..50]}"
  
  puts "\n=== DIAGNOSIS ==="
  puts "The test environment needs:"
  puts "1. Database migrations run for 'test' schema"
  puts "2. Initial data seeded in 'test' schema"
  puts "3. Proper Rails environment initialization"
  puts ""
  puts "Container exec is failing because Rails can't initialize properly"
  puts "due to database schema/environment mismatch."
  puts ""
  puts "RECOMMENDED ACTIONS:"
  puts "1. Fix container environment variables (already done)"
  puts "2. Run: az containerapp exec --command 'bundle exec rails db:migrate'"
  puts "3. Run: az containerapp exec --command 'bundle exec rails db:seed'"
  puts "4. Then run the VoiceLinkAI seeder"
  
rescue => e
  puts "❌ ERROR: #{e.message}"
  puts e.backtrace.first(3)
end 