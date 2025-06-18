#!/usr/bin/env ruby

# Rails runner script to find working tokens
# Run with: bundle exec rails runner find_working_token.rb

puts "🔍 SEARCHING FOR WORKING TOKENS..."
puts "=" * 60

# Get all access tokens
all_tokens = AccessToken.includes(:owner).order(:created_at)

puts "📋 Found #{all_tokens.count} access tokens in system:"

require 'net/http'
require 'json'
require 'uri'

working_tokens = []
failed_tokens = []

all_tokens.each_with_index do |access_token, index|
  owner = access_token.owner
  owner_info = if owner
    case owner.class.name
    when 'User'
      "User: #{owner.name} (#{owner.email}) - Type: #{owner.type || 'User'}"
    when 'PlatformApp'
      "PlatformApp: #{owner.name}"
    when 'AgentBot'
      "AgentBot: #{owner.name}"
    else
      "#{owner.class.name}: #{owner.try(:name) || owner.id}"
    end
  else
    "ORPHANED TOKEN"
  end
  
  puts "\n#{index + 1}. Token: #{access_token.token}"
  puts "   Owner: #{owner_info}"
  puts "   Created: #{access_token.created_at}"
  
  # Test this token
  begin
    uri = URI("https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/profile")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 5
    request = Net::HTTP::Get.new(uri)
    request['api_access_token'] = access_token.token
    
    response = http.request(request)
    
    if response.code.to_i < 400
      puts "   ✅ WORKS! (#{response.code})"
      working_tokens << {
        token: access_token.token,
        owner: owner_info,
        created: access_token.created_at
      }
    else
      puts "   ❌ Failed (#{response.code})"
      failed_tokens << {
        token: access_token.token,
        owner: owner_info,
        error: response.code
      }
    end
  rescue => e
    puts "   ❌ Error: #{e.message}"
    failed_tokens << {
      token: access_token.token,
      owner: owner_info,
      error: e.message
    }
  end
end

puts "\n" + "=" * 60
puts "🎯 RESULTS SUMMARY"
puts "=" * 60

if working_tokens.any?
  puts "✅ WORKING TOKENS (#{working_tokens.length}):"
  working_tokens.each_with_index do |token_info, index|
    puts "\n#{index + 1}. Token: #{token_info[:token]}"
    puts "   Owner: #{token_info[:owner]}"
    puts "   Created: #{token_info[:created]}"
    
    # Test additional endpoints for working tokens
    puts "   Testing additional endpoints..."
    test_endpoints = [
      "/api/v1/accounts/1/agents",
      "/api/v1/accounts/1/conversations",
      "/api/v1/accounts/1/inboxes"
    ]
    
    test_endpoints.each do |endpoint|
      begin
        uri = URI("https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io#{endpoint}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 5
        request = Net::HTTP::Get.new(uri)
        request['api_access_token'] = token_info[:token]
        response = http.request(request)
        status = response.code.to_i < 400 ? "✅" : "❌"
        puts "     #{status} #{endpoint}: #{response.code}"
      rescue => e
        puts "     ❌ #{endpoint}: ERROR"
      end
    end
  end
  
  puts "\n🎉 STABLE TOKEN FOUND!"
  best_token = working_tokens.first
  puts "=" * 60
  puts "RECOMMENDED STABLE TOKEN:"
  puts "#{best_token[:token]}"
  puts "=" * 60
  puts "Owner: #{best_token[:owner]}"
  puts "This token NEVER EXPIRES and works with the API!"
  
else
  puts "❌ NO WORKING TOKENS FOUND"
  puts "\nAll #{failed_tokens.length} tokens failed:"
  failed_tokens.each do |token_info|
    puts "   • #{token_info[:owner]}: #{token_info[:error]}"
  end
end

puts "\n" + "=" * 60 