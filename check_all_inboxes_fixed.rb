#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

puts "📋 Checking All Existing Inboxes (Fixed)..."

# Configuration
base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
account_id = 1
api_token = 'baea8676c67aba47c08564ce'

puts "\n🔗 API Configuration:"
puts "   Base URL: #{base_url}"
puts "   Account ID: #{account_id}"

# Helper function to make API requests
def make_api_request(method, url, headers, body = nil)
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  
  case method.upcase
  when 'GET'
    request = Net::HTTP::Get.new(uri)
  end
  
  headers.each { |key, value| request[key] = value }
  request.body = body.to_json if body
  
  http.request(request)
end

# Get all inboxes
puts "\n📋 Fetching all inboxes..."

headers = {
  'api_access_token' => api_token,
  'Content-Type' => 'application/json',
  'Accept' => 'application/json'
}

inboxes_url = "#{base_url}/api/v1/accounts/#{account_id}/inboxes"
response = make_api_request('GET', inboxes_url, headers)

puts "   Response Code: #{response.code}"

if response.code.to_i != 200
  puts "❌ Failed to fetch inboxes: #{response.code} #{response.message}"
  puts "   Response: #{response.body}" if response.body
  exit 1
end

puts "   Raw Response: #{response.body[0..200]}..." if response.body

begin
  parsed_response = JSON.parse(response.body)
  puts "   Response Type: #{parsed_response.class}"
  
  # Handle different response formats
  if parsed_response.is_a?(Array)
    inboxes = parsed_response
  elsif parsed_response.is_a?(Hash)
    # Check for common wrapper keys
    inboxes = parsed_response['data'] || parsed_response['inboxes'] || parsed_response['payload'] || [parsed_response]
  else
    puts "❌ Unexpected response format: #{parsed_response.class}"
    exit 1
  end
  
  puts "   ✅ Found #{inboxes.length} total inboxes"
rescue JSON::ParserError => e
  puts "❌ Failed to parse inboxes response: #{e.message}"
  puts "   Raw response: #{response.body}"
  exit 1
end

# Display all inboxes with details
puts "\n📊 All Inboxes Details:"

if inboxes.empty?
  puts "   📭 No inboxes found"
else
  inboxes.each_with_index do |inbox, index|
    puts "\n#{index + 1}. Inbox Details:"
    
    # Handle both hash and object formats
    if inbox.is_a?(Hash)
      puts "   ID: #{inbox['id'] || 'N/A'}"
      puts "   Name: #{inbox['name'] || 'N/A'}"
      puts "   Channel Type: #{inbox['channel_type'] || 'N/A'}"
      puts "   Phone Number: #{inbox['phone_number'] || 'N/A'}"
      puts "   Provider: #{inbox['provider'] || 'N/A'}"
      puts "   Webhook URL: #{inbox['callback_webhook_url'] || 'N/A'}"
      puts "   Website Token: #{inbox['website_token'] || 'N/A'}"
      puts "   Business Name: #{inbox['business_name'] || 'N/A'}"
      puts "   Timezone: #{inbox['timezone'] || 'N/A'}"
      puts "   Auto Assignment: #{inbox['enable_auto_assignment']}"
      puts "   CSAT Enabled: #{inbox['csat_survey_enabled']}"
    else
      puts "   Raw Data: #{inbox.inspect}"
    end
  end
end

# Look for any phone numbers that might be similar
puts "\n🔍 Analyzing phone numbers..."

phone_numbers = inboxes.map do |inbox|
  if inbox.is_a?(Hash)
    inbox['phone_number']
  else
    nil
  end
end.compact.uniq

puts "   📱 Unique phone numbers found: #{phone_numbers.length}"

phone_numbers.each do |phone|
  puts "      - #{phone}"
end

# Check for potential duplicates (different formats of same number)
target_numbers = ['19795412927', '+19795412927', '1-979-541-2927', '(979) 541-2927']
puts "\n🔍 Checking for variations of target number..."

target_numbers.each do |target|
  matching_inboxes = inboxes.select do |inbox|
    if inbox.is_a?(Hash)
      inbox['phone_number'] == target
    else
      false
    end
  end
  
  if matching_inboxes.any?
    puts "   📞 Found #{matching_inboxes.length} inbox(es) with #{target}:"
    matching_inboxes.each do |inbox|
      puts "      - Inbox #{inbox['id']}: #{inbox['name']}"
    end
  else
    puts "   ❌ No inboxes found with #{target}"
  end
end

# Check webhook URLs for phone number patterns
puts "\n🔍 Checking webhook URLs for phone number patterns..."

inboxes.each do |inbox|
  if inbox.is_a?(Hash)
    webhook_url = inbox['callback_webhook_url']
    if webhook_url && webhook_url.include?('19795412927')
      puts "   📞 Found phone number in webhook URL:"
      puts "      Inbox #{inbox['id']}: #{inbox['name']}"
      puts "      Webhook: #{webhook_url}"
    end
  end
end

puts "\n✨ Inbox analysis completed!" 