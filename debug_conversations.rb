require 'net/http'
require 'json'
require 'uri'

base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
token = 'baea8676c67aba47c08564ce'

puts '🔍 DEBUGGING CONVERSATIONS API'
puts '=' * 40

http = Net::HTTP.new(URI(base_url).host, URI(base_url).port)
http.use_ssl = true

uri = URI("#{base_url}/api/v1/accounts/1/conversations")
request = Net::HTTP::Get.new(uri)
request['api_access_token'] = token

response = http.request(request)
puts "Status: #{response.code}"
puts "Raw Response Body:"
puts response.body

puts "\nParsed JSON:"
begin
  data = JSON.parse(response.body)
  puts "Type: #{data.class}"
  puts "Keys: #{data.keys if data.is_a?(Hash)}"
  
  if data.is_a?(Hash)
    data.each do |key, value|
      puts "  #{key}: #{value.class}"
      if value.is_a?(Array) && value.length > 0
        puts "    Array length: #{value.length}"
        puts "    First item type: #{value.first.class}"
        if value.first.is_a?(Hash)
          puts "    First item keys: #{value.first.keys}"
        end
      end
    end
  end
rescue JSON::ParserError => e
  puts "JSON Parse Error: #{e.message}"
end 