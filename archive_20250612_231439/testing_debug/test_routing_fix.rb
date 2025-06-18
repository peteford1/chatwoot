#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'

# Test Routing Fix Validation
def test_routing_fixes
  puts "🔍 Testing Routing Fixes..."
  
  base_url = "https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
  gateway_url = "https://voicelinkai.com"
  
  results = {}
  
  # Test 1: Direct backend /cable endpoint
  puts "\n1. Testing direct backend /cable endpoint..."
  begin
    uri = URI("#{base_url}/cable")
    response = Net::HTTP.get_response(uri)
    
    puts "   Status: #{response.code}"
    puts "   Headers: #{response.to_hash.keys.join(', ')}"
    
    if response.code == '404'
      results[:backend_cable] = "❌ Still returns 404 - ActionCable not properly mounted"
    elsif response.code == '426' || response['upgrade']
      results[:backend_cable] = "✅ WebSocket upgrade required - ActionCable working"
    else
      results[:backend_cable] = "⚠️ Unexpected response: #{response.code}"
    end
  rescue => e
    results[:backend_cable] = "❌ Error: #{e.message}"
  end
  
  # Test 2: Gateway /cable endpoint
  puts "\n2. Testing gateway /cable endpoint..."
  begin
    uri = URI("#{gateway_url}/cable")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 10
    
    request = Net::HTTP::Get.new(uri)
    request['Connection'] = 'Upgrade'
    request['Upgrade'] = 'websocket'
    request['Sec-WebSocket-Key'] = 'dGhlIHNhbXBsZSBub25jZQ=='
    request['Sec-WebSocket-Version'] = '13'
    
    response = http.request(request)
    
    puts "   Status: #{response.code}"
    puts "   Headers: #{response.to_hash.keys.join(', ')}"
    
    if response.code == '101'
      results[:gateway_cable] = "✅ WebSocket upgrade successful"
    elsif response.code == '426'
      results[:gateway_cable] = "✅ WebSocket upgrade required - Gateway working"
    else
      results[:gateway_cable] = "⚠️ Response: #{response.code} - #{response.message}"
    end
  rescue => e
    if e.message.include?('Connection reset')
      results[:gateway_cable] = "❌ Connection reset - Gateway SSL/proxy issue"
    else
      results[:gateway_cable] = "❌ Error: #{e.message}"
    end
  end
  
  # Test 3: Super Admin page (should still work)
  puts "\n3. Testing Super Admin page..."
  begin
    uri = URI("#{base_url}/super_admin")
    response = Net::HTTP.get_response(uri)
    
    if response.code == '302' && response['location']&.include?('sign_in')
      results[:super_admin] = "✅ Super Admin redirect working"
    else
      results[:super_admin] = "⚠️ Unexpected response: #{response.code}"
    end
  rescue => e
    results[:super_admin] = "❌ Error: #{e.message}"
  end
  
  # Test 4: API endpoint (should still work)
  puts "\n4. Testing API endpoint..."
  begin
    uri = URI("#{base_url}/api/v1/profile")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = 'Bearer baea8676c67aba47c08564ce'
    
    response = http.request(request)
    
    if response.code == '200'
      results[:api_profile] = "✅ API working"
    else
      results[:api_profile] = "⚠️ Response: #{response.code}"
    end
  rescue => e
    results[:api_profile] = "❌ Error: #{e.message}"
  end
  
  # Summary
  puts "\n" + "="*60
  puts "🎯 ROUTING FIX TEST RESULTS"
  puts "="*60
  
  results.each do |test, result|
    puts "#{test.to_s.ljust(20)}: #{result}"
  end
  
  # Overall status
  success_count = results.values.count { |r| r.start_with?('✅') }
  total_count = results.size
  
  puts "\n📊 Overall: #{success_count}/#{total_count} tests passing"
  
  if success_count == total_count
    puts "🎉 All routing fixes successful!"
  elsif success_count >= total_count - 1
    puts "⚠️ Most fixes working, minor issues remain"
  else
    puts "❌ Significant routing issues still present"
  end
end

# Run the tests
test_routing_fixes 