#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

# Configuration
API_BASE = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
TOKEN = '341179b44e238f00c018e9b8e98fcf620a9ff567745efd8d4dd7613b9b5a33f9'
ACCOUNT_ID = 1

def test_token
  puts "🔍 Testing API token..."
  puts "Token: #{TOKEN[0..20]}..."
  
  # Test 1: Get account info
  puts "\n1. Testing account access:"
  uri = URI("#{API_BASE}/api/v1/accounts/#{ACCOUNT_ID}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  
  request = Net::HTTP::Get.new(uri)
  request['api_access_token'] = TOKEN
  
  response = http.request(request)
  puts "   Status: #{response.code}"
  puts "   Response: #{response.body[0..100]}..."
  
  # Test 2: Get agents
  puts "\n2. Testing agents access:"
  uri = URI("#{API_BASE}/api/v1/accounts/#{ACCOUNT_ID}/agents")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  
  request = Net::HTTP::Get.new(uri)
  request['api_access_token'] = TOKEN
  
  response = http.request(request)
  puts "   Status: #{response.code}"
  puts "   Response: #{response.body[0..100]}..."
  
  # Test 3: Get inboxes
  puts "\n3. Testing inboxes access:"
  uri = URI("#{API_BASE}/api/v1/accounts/#{ACCOUNT_ID}/inboxes")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  
  request = Net::HTTP::Get.new(uri)
  request['api_access_token'] = TOKEN
  
  response = http.request(request)
  puts "   Status: #{response.code}"
  puts "   Response: #{response.body[0..100]}..."
  
  if response.code == '200'
    puts "\n✅ Token works! Ready for SMS test."
  else
    puts "\n❌ Token not working. Need to create a new one."
  end
end

test_token 