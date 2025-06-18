#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

# Check what inbox 6 is
uri = URI('https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/accounts/1/inboxes/6')
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

request = Net::HTTP::Get.new(uri)
request['api_access_token'] = 'baea8676c67aba47c08564ce'

response = http.request(request)
if response.code == '200'
  data = JSON.parse(response.body)
  puts 'Inbox 6 Details:'
  puts "  Name: #{data['name']}"
  puts "  Channel Type: #{data['channel_type']}"
  puts "  Phone Number: #{data['phone_number']}" if data['phone_number']
  puts "  Provider: #{data['provider_config']}" if data['provider_config']
  
  # Check if it's a Twilio SMS channel
  if data['channel_type'] == 'Channel::TwilioSms'
    puts "  📱 This is a Twilio SMS channel"
    puts "  📞 Phone Number: #{data['phone_number']}" if data['phone_number']
  end
else
  puts "Failed to get inbox details: #{response.code}"
  puts response.body
end 