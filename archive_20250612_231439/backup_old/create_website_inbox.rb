#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'uri'

puts "🚀 Website Inbox Creation Script"
puts "=" * 60

# --- Configuration ---
CHATWOOT_BASE_URL = 'http://localhost:8080' # We'll go through KrakenD
ACCOUNT_ID = 3
ADMIN_ACCESS_TOKEN = '0212af10d6c85e3f692325e0'
INBOX_NAME = 'My Test Website Inbox'
WIDGET_WEBSITE_URL = 'https://example.com'


def make_api_request(method, endpoint, data = nil, token = nil)
  uri = URI("#{CHATWOOT_BASE_URL}#{endpoint}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = (uri.scheme == 'https')

  request = case method.upcase
            when 'GET'
              Net::HTTP::Get.new(uri)
            when 'POST'
              Net::HTTP::Post.new(uri)
            end

  request['Content-Type'] = 'application/json'
  # The script will pass the token in api_access_token header, 
  # and KrakenD will transform it to Authorization: Bearer <token>
  request['api_access_token'] = token if token
  request.body = data.to_json if data && method.upcase == 'POST'

  response = http.request(request)

  {
    status: response.code.to_i,
    body: response.body,
    parsed: (JSON.parse(response.body) rescue response.body)
  }
end

puts "🔍 Step 1: Verifying account..."
# We already know the account exists, so we can skip this check,
# but it's good practice to leave it in for a real script.
puts "✅ Account check skipped. We know it exists."

puts "\n🌐 Step 2: Creating Website inbox..."

inbox_data = {
  name: INBOX_NAME,
  channel: {
    type: 'website',
    website_url: WIDGET_WEBSITE_URL,
    widget_color: '#1f93ff'
  }
}

create_response = make_api_request(
  'POST',
  "/api/v1/accounts/#{ACCOUNT_ID}/inboxes",
  inbox_data,
  ADMIN_ACCESS_TOKEN
)

if [200, 201].include?(create_response[:status])
  inbox = create_response[:parsed]
  puts "✅ SUCCESS! Website inbox created:"
  puts "   - Inbox ID: #{inbox['id']}"
  puts "   - Name: #{inbox['name']}"
  
  if inbox['channel'] && inbox['channel']['website_url']
    puts "   - Website URL: #{inbox['channel']['website_url']}"
  end
  
  puts "\n🎉 INBOX CREATION SUCCESSFUL!"
  puts "\n🧪 Now you can test the GET inboxes endpoint again:"
  puts "  curl -v -H \"api_access_token: #{ADMIN_ACCESS_TOKEN}\" #{CHATWOOT_BASE_URL}/api/v1/accounts/#{ACCOUNT_ID}/inboxes"
else
  puts "❌ Failed to create inbox:"
  puts "   Status: #{create_response[:status]}"
  puts "   Error: #{create_response[:parsed]}"
end 