#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

# API configuration
API_BASE = 'https://chatwoot-backend-test.proudsea-c0c0c6c0.eastus.azurecontainerapps.io'
API_TOKEN = 'baea8676c67aba47c08564ce'

def make_api_request(endpoint, method = 'GET', body = nil)
  uri = URI("#{API_BASE}#{endpoint}")
  
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  
  case method.upcase
  when 'GET'
    request = Net::HTTP::Get.new(uri)
  when 'POST'
    request = Net::HTTP::Post.new(uri)
    request.body = body.to_json if body
    request['Content-Type'] = 'application/json'
  when 'DELETE'
    request = Net::HTTP::Delete.new(uri)
  end
  
  request['api_access_token'] = API_TOKEN
  
  response = http.request(request)
  
  puts "#{method} #{endpoint}"
  puts "Status: #{response.code} #{response.message}"
  
  if response.body && !response.body.empty?
    begin
      JSON.parse(response.body)
    rescue JSON::ParserError
      response.body
    end
  else
    nil
  end
end

puts "=== Checking Current Inbox Status ==="
inboxes = make_api_request('/api/v1/accounts/1/inboxes')
if inboxes.is_a?(Array)
  puts "\nCurrent Inboxes:"
  inboxes.each do |inbox|
    puts "  ID: #{inbox['id']}, Name: #{inbox['name']}, Channel: #{inbox['channel_type']}"
  end
else
  puts "Unexpected response format: #{inboxes.class}"
  puts inboxes.inspect
end

puts "\n=== Checking if jobs are still running ==="
puts "Jobs were enqueued around 11:55 UTC (#{Time.now.utc} current time)"
puts "Time elapsed: #{((Time.now.utc - Time.parse('2025-06-13 11:55:52 UTC')) / 60).round(1)} minutes"

puts "\n=== Recommendations ==="
puts "1. Jobs are in 'low' priority queue - they may take longer to process"
puts "2. Check if Sidekiq workers are configured to process 'low' queue"
puts "3. Consider checking Sidekiq web UI if available"
puts "4. May need to wait longer or check for database constraints preventing deletion" 