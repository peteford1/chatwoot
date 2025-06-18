#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'

puts "🔌 Testing ActionCable WebSocket Connections..."
puts "=" * 60

# Test endpoints
endpoints = {
  "Direct Backend" => "https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/cable",
  "KrakenD Gateway" => "https://voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io/cable"
}

def test_websocket_endpoint(name, url)
  puts "\n#{name}:"
  puts "URL: #{url}"
  
  begin
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 10
    
    # Test 1: Regular HTTP GET (should return upgrade required)
    puts "  1. HTTP GET test..."
    request = Net::HTTP::Get.new(uri)
    response = http.request(request)
    
    puts "     Status: #{response.code} #{response.message}"
    puts "     Headers: #{response.to_hash.select { |k,v| k.downcase.include?('upgrade') || k.downcase.include?('connection') }}"
    
    if response.code == '426' || response.code == '101'
      puts "     ✅ WebSocket upgrade available"
    elsif response.code == '404'
      puts "     ❌ Endpoint not found"
      return false
    else
      puts "     ⚠️  Unexpected response: #{response.code}"
    end
    
    # Test 2: WebSocket upgrade request
    puts "  2. WebSocket upgrade test..."
    ws_request = Net::HTTP::Get.new(uri)
    ws_request['Connection'] = 'Upgrade'
    ws_request['Upgrade'] = 'websocket'
    ws_request['Sec-WebSocket-Key'] = 'dGhlIHNhbXBsZSBub25jZQ=='
    ws_request['Sec-WebSocket-Version'] = '13'
    ws_request['Sec-WebSocket-Protocol'] = 'actioncable-v1-json'
    
    ws_response = http.request(ws_request)
    puts "     Status: #{ws_response.code} #{ws_response.message}"
    
    if ws_response.code == '101'
      puts "     ✅ WebSocket upgrade successful!"
      return true
    elsif ws_response.code == '426'
      puts "     ✅ WebSocket upgrade required (normal for ActionCable)"
      return true
    else
      puts "     ❌ WebSocket upgrade failed: #{ws_response.code}"
      return false
    end
    
  rescue => e
    puts "     ❌ Connection error: #{e.message}"
    return false
  end
end

# Test both endpoints
results = {}
endpoints.each do |name, url|
  results[name] = test_websocket_endpoint(name, url)
end

# Summary
puts "\n" + "=" * 60
puts "SUMMARY:"
results.each do |name, success|
  status = success ? "✅ WORKING" : "❌ FAILED"
  puts "#{name}: #{status}"
end

# Recommendations
puts "\nRECOMMENDATIONS:"
if results["KrakenD Gateway"]
  puts "✅ Use KrakenD Gateway for WebSocket connections"
  puts "   wss://voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io/cable"
elsif results["Direct Backend"]
  puts "⚠️  Use Direct Backend (KrakenD proxy has issues)"
  puts "   wss://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/cable"
else
  puts "❌ Both endpoints failed - ActionCable may not be properly configured"
end

puts "\nNext steps:"
puts "1. If KrakenD works: Update frontend to use gateway WebSocket URL"
puts "2. If only direct works: Check KrakenD WebSocket proxy configuration"
puts "3. If both fail: Check ActionCable mount and Redis configuration"
