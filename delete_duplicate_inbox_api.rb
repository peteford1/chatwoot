#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'
require 'fileutils'

puts "🗑️  Deleting Duplicate Inbox via API..."

# Configuration
base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
account_id = 1
api_token = 'baea8676c67aba47c08564ce'
phone_number = '19795412927'
phone_number_with_plus = '+19795412927'

puts "\n🔗 API Configuration:"
puts "   Base URL: #{base_url}"
puts "   Account ID: #{account_id}"
puts "   Target Phone: #{phone_number} / #{phone_number_with_plus}"

# Helper function to make API requests
def make_api_request(method, url, headers, body = nil)
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  
  case method.upcase
  when 'GET'
    request = Net::HTTP::Get.new(uri)
  when 'DELETE'
    request = Net::HTTP::Delete.new(uri)
  when 'POST'
    request = Net::HTTP::Post.new(uri)
  when 'PATCH'
    request = Net::HTTP::Patch.new(uri)
  end
  
  headers.each { |key, value| request[key] = value }
  request.body = body.to_json if body
  
  http.request(request)
end

# Step 1: Get all inboxes
puts "\n📋 Fetching all inboxes..."

headers = {
  'api_access_token' => api_token,
  'Content-Type' => 'application/json',
  'Accept' => 'application/json'
}

inboxes_url = "#{base_url}/api/v1/accounts/#{account_id}/inboxes"
response = make_api_request('GET', inboxes_url, headers)

if response.code.to_i != 200
  puts "❌ Failed to fetch inboxes: #{response.code} #{response.message}"
  puts "   Response: #{response.body}" if response.body
  exit 1
end

begin
  inboxes = JSON.parse(response.body)
  puts "   ✅ Found #{inboxes.length} total inboxes"
rescue JSON::ParserError => e
  puts "❌ Failed to parse inboxes response: #{e.message}"
  exit 1
end

# Step 2: Find duplicate phone numbers
puts "\n🔍 Searching for duplicate phone numbers..."

duplicate_inboxes = inboxes.select do |inbox|
  phone = inbox['phone_number']
  phone == phone_number || phone == phone_number_with_plus
end

puts "   📱 Found #{duplicate_inboxes.length} inboxes with phone number #{phone_number}:"

if duplicate_inboxes.empty?
  puts "   ✅ No duplicate inboxes found"
  exit 0
end

duplicate_inboxes.each_with_index do |inbox, index|
  puts "\n#{index + 1}. Inbox ID: #{inbox['id']}"
  puts "   Name: #{inbox['name']}"
  puts "   Channel Type: #{inbox['channel_type']}"
  puts "   Phone: #{inbox['phone_number']}"
  puts "   Provider: #{inbox['provider']}"
  puts "   Webhook URL: #{inbox['callback_webhook_url']}"
end

# Step 3: Determine which inbox to delete
if duplicate_inboxes.length >= 2
  puts "\n🤔 Determining which inbox to delete..."
  
  # Prefer to keep the one with proper international format (+)
  inbox_to_keep = duplicate_inboxes.find { |inbox| inbox['phone_number'].start_with?('+') }
  inbox_to_keep ||= duplicate_inboxes.first # If no + format, keep the first one
  
  inbox_to_delete = duplicate_inboxes.find { |inbox| inbox['id'] != inbox_to_keep['id'] }
  
  puts "\n📌 RECOMMENDATION:"
  puts "   ✅ KEEP: Inbox #{inbox_to_keep['id']} (#{inbox_to_keep['name']})"
  puts "      Phone: #{inbox_to_keep['phone_number']}"
  puts "      Channel: #{inbox_to_keep['channel_type']}"
  puts "      Reason: #{inbox_to_keep['phone_number'].start_with?('+') ? 'Proper international format' : 'First found'}"
  
  puts "\n   🗑️  DELETE: Inbox #{inbox_to_delete['id']} (#{inbox_to_delete['name']})"
  puts "      Phone: #{inbox_to_delete['phone_number']}"
  puts "      Channel: #{inbox_to_delete['channel_type']}"
  puts "      Reason: #{inbox_to_delete['phone_number'].start_with?('+') ? 'Duplicate' : 'Wrong format'}"
  
  # Create backup info before deletion
  puts "\n💾 Creating backup information..."
  
  backup_info = {
    deletion_timestamp: Time.now.iso8601,
    account_id: account_id,
    inbox_to_keep: inbox_to_keep,
    inbox_to_delete: inbox_to_delete,
    reason: "Duplicate phone number cleanup",
    phone_number: phone_number,
    api_token_used: api_token[0..8] + "..." # Partial token for reference
  }
  
  backup_file = "backup/inbox_deletion_#{inbox_to_delete['id']}_#{Time.now.to_i}.json"
  FileUtils.mkdir_p("backup")
  File.write(backup_file, JSON.pretty_generate(backup_info))
  puts "   📄 Backup saved: #{backup_file}"
  
  # Step 4: Delete the duplicate inbox
  puts "\n🚀 Proceeding with inbox deletion..."
  puts "   Target: Inbox #{inbox_to_delete['id']} (#{inbox_to_delete['name']})"
  
  delete_url = "#{base_url}/api/v1/accounts/#{account_id}/inboxes/#{inbox_to_delete['id']}"
  puts "   📡 Sending DELETE request..."
  
  delete_response = make_api_request('DELETE', delete_url, headers)
  
  case delete_response.code.to_i
  when 200..299
    puts "   ✅ SUCCESS: Inbox deleted successfully"
    puts "      Status: #{delete_response.code} #{delete_response.message}"
    
    # Update backup with success status
    backup_info[:deletion_status] = "success"
    backup_info[:deletion_response_code] = delete_response.code.to_i
    File.write(backup_file, JSON.pretty_generate(backup_info))
    
    # Verify deletion by trying to fetch the inbox
    puts "\n🔍 Verifying deletion..."
    verify_response = make_api_request('GET', delete_url, headers)
    
    if verify_response.code.to_i == 404
      puts "   ✅ Confirmed: Inbox no longer exists"
    else
      puts "   ⚠️  Warning: Inbox may still exist (status: #{verify_response.code})"
    end
    
  when 400..499
    puts "   ❌ CLIENT ERROR: #{delete_response.code} #{delete_response.message}"
    if delete_response.body
      begin
        error_data = JSON.parse(delete_response.body)
        puts "      Error: #{error_data['message'] || error_data['error']}"
      rescue JSON::ParserError
        puts "      Response: #{delete_response.body[0..200]}"
      end
    end
    
    backup_info[:deletion_status] = "failed"
    backup_info[:deletion_error] = delete_response.body
    File.write(backup_file, JSON.pretty_generate(backup_info))
    
  when 500..599
    puts "   💥 SERVER ERROR: #{delete_response.code} #{delete_response.message}"
    if delete_response.body
      puts "      Response: #{delete_response.body[0..200]}"
    end
    
    backup_info[:deletion_status] = "server_error"
    backup_info[:deletion_error] = delete_response.body
    File.write(backup_file, JSON.pretty_generate(backup_info))
    
  else
    puts "   ⚠️  UNEXPECTED RESPONSE: #{delete_response.code} #{delete_response.message}"
    backup_info[:deletion_status] = "unexpected"
    backup_info[:deletion_error] = delete_response.body
    File.write(backup_file, JSON.pretty_generate(backup_info))
  end
  
  # Step 5: Final verification - list remaining inboxes
  puts "\n📊 Final verification - checking remaining inboxes..."
  
  final_response = make_api_request('GET', inboxes_url, headers)
  if final_response.code.to_i == 200
    final_inboxes = JSON.parse(final_response.body)
    remaining_duplicates = final_inboxes.select do |inbox|
      phone = inbox['phone_number']
      phone == phone_number || phone == phone_number_with_plus
    end
    
    puts "   📱 Remaining inboxes with phone #{phone_number}: #{remaining_duplicates.length}"
    remaining_duplicates.each do |inbox|
      puts "      - Inbox #{inbox['id']}: #{inbox['name']} (#{inbox['phone_number']})"
    end
    
    if remaining_duplicates.length == 1
      puts "   ✅ SUCCESS: Duplicate resolved! Only one inbox remains."
    elsif remaining_duplicates.length == 0
      puts "   ⚠️  WARNING: No inboxes remain with this phone number!"
    else
      puts "   ⚠️  WARNING: Multiple inboxes still exist!"
    end
  end
  
else
  puts "\n✅ Only one inbox found - no deletion needed"
end

puts "\n✨ Duplicate inbox cleanup completed!"
puts "   📄 Backup file: #{backup_file}" if defined?(backup_file) 