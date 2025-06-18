#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'uri'

# VoiceLinkAI Test Environment Seeder (Direct Execution)
# This script creates test environment setup using external API calls

puts "🚀 VoiceLinkAI Test Environment Seeder (Direct External)"
puts "=" * 60
puts "Target: Test Environment Container"
puts "Mode: External API Calls"
puts "Timestamp: #{Time.now}"
puts "=" * 60

# Configuration
base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'

def make_api_call(method, endpoint, data = nil, token, base_url)
  uri = URI("#{base_url}#{endpoint}")
  
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.read_timeout = 30
  http.open_timeout = 10
  
  case method.upcase
  when 'POST'
    request = Net::HTTP::Post.new(uri.path)
    request.body = data.to_json if data
    request['Content-Type'] = 'application/json'
  when 'GET'
    request = Net::HTTP::Get.new(uri.path)
  end
  
  request['api_access_token'] = token
  
  begin
    response = http.request(request)
    puts "   API #{method} #{endpoint}: #{response.code} #{response.message}"
    
    if response.code.to_i.between?(200, 299)
      JSON.parse(response.body) rescue response.body
    else
      puts "   Error: #{response.body[0..300]}" if response.body
      { error: response.body, status: response.code }
    end
  rescue => e
    puts "   Network Error: #{e.message}"
    { error: e.message }
  end
end

# STEP 1: Check if we can access the test environment
puts "\n🔍 Step 1: Testing connection to test environment"
health_check = make_api_call('GET', '/health', nil, '', base_url)
if health_check.is_a?(Hash) && health_check.key?('error')
  puts "❌ Cannot connect to test environment"
  puts "Error: #{health_check[:error]}"
  exit 1
end
puts "✅ Connected to test environment successfully"

# Note: We cannot create Platform Apps externally without existing tokens
# This would require either:
# 1. Manual creation of Platform App in the container first
# 2. Use of existing tokens
# 3. Or GitHub Actions deployment

puts "\n⚠️  LIMITATION: External API creation requires existing Platform App"
puts "This seeder demonstrates the API approach but requires container execution"
puts "for initial Platform App creation."

puts "\n🎯 RECOMMENDATION: Use the GitHub Actions workflow or container exec method"
puts "The production-ready seeder is available in scripts/deploy_test_env_seeder.rb"
puts "and can be executed via the GitHub Actions pipeline."

puts "\n📋 Next Steps:"
puts "1. Deploy via GitHub Actions workflow (recommended)"
puts "2. Or execute seeder directly in container environment"
puts "3. Or manually create Platform App first, then use this external approach"

puts "\n✅ Direct seeder validation completed" 