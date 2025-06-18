#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

puts "🔍 Testing Inbox Update API Issues..."

# Test the exact curl request to identify problems
base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
account_id = 1
inbox_id = 2
api_token = 'baea8676c67aba47c08564ce'

# The problematic request data from the curl
request_data = {
  "name" => "VoiceLinkAI - SMS (+19795412927)",
  "provider" => "twilio",
  "provider_config" => {
    "account_sid" => "AC62c0b1130dca59524440547d60dd10a9",
    "auth_token" => "b231d945a3de6b361d9751f0807b50dc",
    "phone_number" => "+19795412927"
  }
}

puts "\n🚨 ISSUES IDENTIFIED:"
puts "1. ❌ WRONG STRUCTURE: 'provider' and 'provider_config' should be nested under 'channel'"
puts "2. ❌ MISSING CHANNEL WRAPPER: Twilio credentials need to be in channel object"
puts "3. ❌ INCORRECT FIELD NAMES: Should use 'account_sid', 'auth_token' directly"

puts "\n📋 CORRECT REQUEST STRUCTURE:"
correct_data = {
  "name" => "VoiceLinkAI - SMS (+19795412927)",
  "channel" => {
    "account_sid" => "AC62c0b1130dca59524440547d60dd10a9",
    "auth_token" => "b231d945a3de6b361d9751f0807b50dc",
    "phone_number" => "+19795412927"
  }
}

puts JSON.pretty_generate(correct_data)

puts "\n🔧 TESTING BOTH REQUESTS:"

def test_request(url, headers, data, description)
  puts "\n#{description}:"
  
  begin
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    
    request = Net::HTTP::Patch.new(uri)
    headers.each { |key, value| request[key] = value }
    request.body = data.to_json
    
    response = http.request(request)
    
    puts "   Status: #{response.code} #{response.message}"
    
    if response.body && !response.body.empty?
      begin
        parsed = JSON.parse(response.body)
        puts "   Response: #{JSON.pretty_generate(parsed)}"
      rescue JSON::ParserError
        puts "   Response: #{response.body[0..200]}..."
      end
    end
    
    case response.code.to_i
    when 200..299
      puts "   ✅ SUCCESS"
    when 400..499
      puts "   ❌ CLIENT ERROR - Check request format"
    when 500..599
      puts "   💥 SERVER ERROR - Check server logs"
    else
      puts "   ⚠️  UNEXPECTED RESPONSE"
    end
    
  rescue => e
    puts "   💥 ERROR: #{e.message}"
  end
end

headers = {
  'api_access_token' => api_token,
  'Content-Type' => 'application/json',
  'Accept' => 'application/json'
}

url = "#{base_url}/api/v1/accounts/#{account_id}/inboxes/#{inbox_id}"

# Test the original (incorrect) request
test_request(url, headers, request_data, "❌ ORIGINAL (INCORRECT) REQUEST")

# Test the corrected request
test_request(url, headers, correct_data, "✅ CORRECTED REQUEST")

puts "\n📝 SUMMARY OF FIXES NEEDED:"
puts "1. Move 'provider' and 'provider_config' fields into a 'channel' object"
puts "2. Use direct field names (account_sid, auth_token, phone_number) under 'channel'"
puts "3. Remove the 'provider_config' wrapper for Twilio channels"

puts "\n🔧 CORRECT CURL COMMAND:"
puts <<~CURL
curl -X PATCH \\
  '#{url}' \\
  -H 'api_access_token: #{api_token}' \\
  -H 'Content-Type: application/json' \\
  -H 'Accept: application/json' \\
  -d '#{correct_data.to_json}'
CURL

puts "\n✨ Test completed!" 