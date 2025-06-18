#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

puts "🔍 CHATWOOT AUTHENTICATION TEST - ENVIRONMENT BASED"
puts "=" * 60

# Get configuration from environment variables
BASE_URL = ENV['CHATWOOT_API_BASE_URL'] || 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
ACCOUNT_ID = ENV['CHATWOOT_ACCOUNT_ID']
USER_TOKEN = ENV['CHATWOOT_USER_TOKEN']
USER_EMAIL = ENV['CHATWOOT_USER_EMAIL']
ACCOUNT_NAME = ENV['CHATWOOT_ACCOUNT_NAME']

puts "\n📋 CONFIGURATION:"
puts "   API Base URL: #{BASE_URL}"
puts "   Account ID: #{ACCOUNT_ID || 'NOT SET'}"
puts "   Account Name: #{ACCOUNT_NAME || 'NOT SET'}"
puts "   User Email: #{USER_EMAIL || 'NOT SET'}"
puts "   User Token: #{USER_TOKEN ? "#{USER_TOKEN[0..15]}...#{USER_TOKEN[-4..-1]}" : 'NOT SET'}"

if ACCOUNT_ID.nil? || USER_TOKEN.nil?
  puts "\n❌ MISSING CONFIGURATION"
  puts "   Please run the database configuration first:"
  puts "   1. source azure_database_config.env"
  puts "   2. rails runner update_dynamic_account_env.rb"
  puts "   3. source azure_database_config.env  # reload updated config"
  puts "   4. ruby #{__FILE__}"
  exit 1
end

def make_request(method, path, headers = {}, body = nil)
  uri = URI("#{BASE_URL}#{path}")
  
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  http.read_timeout = 30
  
  case method.upcase
  when 'GET'
    request = Net::HTTP::Get.new(uri)
  when 'POST'
    request = Net::HTTP::Post.new(uri)
    request.body = body if body
  when 'PUT'
    request = Net::HTTP::Put.new(uri)
    request.body = body if body
  when 'DELETE'
    request = Net::HTTP::Delete.new(uri)
  end
  
  # Set headers
  headers.each { |key, value| request[key] = value }
  request['Content-Type'] = 'application/json' if body
  
  begin
    response = http.request(request)
    {
      status: response.code.to_i,
      body: response.body,
      headers: response.to_hash
    }
  rescue => e
    {
      status: 0,
      body: "Connection error: #{e.message}",
      headers: {}
    }
  end
end

def test_authentication_method(method_name, headers)
  puts "\n🧪 Testing #{method_name}:"
  
  # Test basic API health
  response = make_request('GET', '/api/v1/profile', headers)
  
  case response[:status]
  when 200
    puts "   ✅ SUCCESS - Authentication working"
    begin
      profile = JSON.parse(response[:body])
      puts "      User: #{profile['name']} (#{profile['email']})"
      puts "      ID: #{profile['id']}"
    rescue JSON::ParserError
      puts "      Response received but not JSON"
    end
    return true
  when 401
    puts "   ❌ FAILED - Invalid token (401 Unauthorized)"
    return false
  when 404
    puts "   ❌ FAILED - Endpoint not found (404)"
    return false
  when 0
    puts "   ❌ FAILED - Connection error"
    puts "      #{response[:body]}"
    return false
  else
    puts "   ❌ FAILED - HTTP #{response[:status]}"
    puts "      #{response[:body][0..200]}"
    return false
  end
end

def test_account_access(headers)
  puts "\n🏢 Testing Account Access:"
  
  response = make_request('GET', "/api/v1/accounts/#{ACCOUNT_ID}", headers)
  
  case response[:status]
  when 200
    puts "   ✅ SUCCESS - Account access working"
    begin
      account = JSON.parse(response[:body])
      puts "      Account: #{account['name']}"
      puts "      ID: #{account['id']}"
      puts "      Status: #{account['status']}"
    rescue JSON::ParserError
      puts "      Response received but not JSON"
    end
    return true
  when 401
    puts "   ❌ FAILED - Unauthorized access to account"
    return false
  when 404
    puts "   ❌ FAILED - Account not found"
    return false
  else
    puts "   ❌ FAILED - HTTP #{response[:status]}"
    return false
  end
end

def test_conversations_access(headers)
  puts "\n💬 Testing Conversations Access:"
  
  response = make_request('GET', "/api/v1/accounts/#{ACCOUNT_ID}/conversations", headers)
  
  case response[:status]
  when 200
    puts "   ✅ SUCCESS - Conversations access working"
    begin
      data = JSON.parse(response[:body])
      conversations = data['data'] || []
      puts "      Found #{conversations.length} conversations"
      
      if conversations.any?
        conv = conversations.first
        puts "      Latest: ID #{conv['id']} - #{conv['meta']['sender']['name'] rescue 'Unknown'}"
      end
    rescue JSON::ParserError
      puts "      Response received but not JSON"
    end
    return true
  when 401
    puts "   ❌ FAILED - Unauthorized access to conversations"
    return false
  when 404
    puts "   ❌ FAILED - Conversations endpoint not found"
    return false
  else
    puts "   ❌ FAILED - HTTP #{response[:status]}"
    return false
  end
end

# Test all authentication methods
puts "\n🔐 TESTING AUTHENTICATION METHODS:"

success_count = 0
total_tests = 3

# Method 1: api_access_token header (Chatwoot standard)
if test_authentication_method("api_access_token header", { 'api_access_token' => USER_TOKEN })
  success_count += 1
  
  # Test additional endpoints with working method
  headers = { 'api_access_token' => USER_TOKEN }
  test_account_access(headers)
  test_conversations_access(headers)
end

# Method 2: Authorization Bearer header (HTTP standard)
if test_authentication_method("Authorization Bearer", { 'Authorization' => "Bearer #{USER_TOKEN}" })
  success_count += 1
end

# Method 3: HTTP_API_ACCESS_TOKEN header (Nginx compatibility)
if test_authentication_method("HTTP_API_ACCESS_TOKEN", { 'HTTP_API_ACCESS_TOKEN' => USER_TOKEN })
  success_count += 1
end

puts "\n" + "=" * 60
puts "🎯 AUTHENTICATION TEST SUMMARY"
puts "=" * 60

if success_count > 0
  puts "✅ SUCCESS: #{success_count}/#{total_tests} authentication methods working"
  puts ""
  puts "🚀 READY FOR SMS WEBSOCKET TESTS!"
  puts "   Your authentication is working correctly."
  puts "   You can now run:"
  puts "   ruby live_websocket_sms_test_auto.rb"
else
  puts "❌ FAILURE: No authentication methods working"
  puts ""
  puts "🔧 TROUBLESHOOTING STEPS:"
  puts "1. Verify database connection:"
  puts "   rails runner \"puts ActiveRecord::Base.connection.current_database\""
  puts ""
  puts "2. Check if user exists in Azure database:"
  puts "   rails runner \"puts User.find_by(email: '#{USER_EMAIL}')&.inspect\""
  puts ""
  puts "3. Verify API server is running:"
  puts "   curl -I #{BASE_URL}/api/v1/profile"
  puts ""
  puts "4. Check network connectivity to Azure:"
  puts "   ping chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
end

puts "\n📊 Environment Status:"
puts "   Database: #{ENV['POSTGRES_DATABASE']} @ #{ENV['POSTGRES_HOST']}"
puts "   Rails Env: #{ENV['RAILS_ENV']}"
puts "   API URL: #{BASE_URL}" 