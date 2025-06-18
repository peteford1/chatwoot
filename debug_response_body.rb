require 'net/http'
require 'json'
require 'uri'

base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
token = 'baea8676c67aba47c08564ce'

puts '🔍 DEBUGGING RESPONSE BODIES'
puts '=' * 50

http = Net::HTTP.new(URI(base_url).host, URI(base_url).port)
http.use_ssl = true

# Test inbox 6 details
puts "\n📥 Testing Inbox 6 Response Body:"
puts "-" * 40

uri = URI("#{base_url}/api/v1/accounts/1/inboxes/6")
request = Net::HTTP::Get.new(uri)
request['api_access_token'] = token

response = http.request(request)
puts "Status: #{response.code}"
puts "Content-Type: #{response['content-type']}"
puts "Content-Length: #{response['content-length']}"

puts "\nRaw Response Body:"
puts response.body

puts "\nParsed JSON:"
begin
  data = JSON.parse(response.body)
  puts "JSON Structure:"
  puts "  Type: #{data.class}"
  puts "  Keys: #{data.keys if data.is_a?(Hash)}"
  puts "  Length: #{data.length if data.respond_to?(:length)}"
  
  if data.is_a?(Hash)
    data.each do |key, value|
      puts "  #{key}: #{value.class} (#{value.nil? ? 'NIL' : 'has value'})"
      if value.nil?
        puts "    ⚠️  This key is null!"
      end
    end
  end
rescue JSON::ParserError => e
  puts "❌ JSON Parse Error: #{e.message}"
end

# Test account details for comparison
puts "\n\n🏢 Testing Account Response Body:"
puts "-" * 40

uri = URI("#{base_url}/api/v1/accounts/1")
request = Net::HTTP::Get.new(uri)
request['api_access_token'] = token

response = http.request(request)
puts "Status: #{response.code}"
puts "Raw Response Body:"
puts response.body

puts "\nParsed JSON:"
begin
  data = JSON.parse(response.body)
  puts "JSON Structure:"
  puts "  Type: #{data.class}"
  puts "  Keys: #{data.keys if data.is_a?(Hash)}"
  
  if data.is_a?(Hash)
    data.each do |key, value|
      puts "  #{key}: #{value.class} (#{value.nil? ? 'NIL' : 'has value'})"
    end
  end
rescue JSON::ParserError => e
  puts "❌ JSON Parse Error: #{e.message}"
end 