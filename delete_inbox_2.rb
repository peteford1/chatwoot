#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'
require 'fileutils'

puts "🗑️  Deleting Duplicate Inbox 2..."

# Configuration
base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
account_id = 1
api_token = 'baea8676c67aba47c08564ce'
inbox_to_delete_id = 2

puts "\n🎯 Target for Deletion:"
puts "   Inbox ID: #{inbox_to_delete_id}"
puts "   Name: VoiceLinkAI - SMS (+19795412927)"
puts "   Phone: 19795412927 (without + prefix)"
puts "   Reason: Duplicate of Inbox 6 which has proper format"

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
  end
  
  headers.each { |key, value| request[key] = value }
  request.body = body.to_json if body
  
  http.request(request)
end

headers = {
  'api_access_token' => api_token,
  'Content-Type' => 'application/json',
  'Accept' => 'application/json'
}

# Step 1: Get details of inbox to be deleted
puts "\n📋 Getting details of inbox to be deleted..."

get_url = "#{base_url}/api/v1/accounts/#{account_id}/inboxes/#{inbox_to_delete_id}"
get_response = make_api_request('GET', get_url, headers)

if get_response.code.to_i == 200
  begin
    inbox_details = JSON.parse(get_response.body)
    puts "   ✅ Found inbox details:"
    puts "      ID: #{inbox_details['id']}"
    puts "      Name: #{inbox_details['name']}"
    puts "      Phone: #{inbox_details['phone_number']}"
    puts "      Channel Type: #{inbox_details['channel_type']}"
    puts "      Webhook: #{inbox_details['callback_webhook_url']}"
  rescue JSON::ParserError
    puts "   ⚠️  Could not parse inbox details"
    inbox_details = { 'id' => inbox_to_delete_id, 'name' => 'Unknown' }
  end
else
  puts "   ❌ Could not fetch inbox details: #{get_response.code}"
  inbox_details = { 'id' => inbox_to_delete_id, 'name' => 'Unknown' }
end

# Step 2: Create backup before deletion
puts "\n💾 Creating backup before deletion..."

backup_info = {
  deletion_timestamp: Time.now.strftime("%Y-%m-%dT%H:%M:%S%z"),
  account_id: account_id,
  inbox_deleted: inbox_details,
  reason: "Duplicate phone number cleanup - keeping inbox 6 with proper +19795412927 format",
  phone_number_issue: "Inbox 2 has '19795412927' without +, Inbox 6 has '+19795412927' with +",
  webhook_conflict: "Both inboxes use same webhook URL ending in /19795412927",
  api_token_used: api_token[0..8] + "..."
}

backup_file = "backup/inbox_2_deletion_#{Time.now.to_i}.json"
FileUtils.mkdir_p("backup")
File.write(backup_file, JSON.pretty_generate(backup_info))
puts "   📄 Backup saved: #{backup_file}"

# Step 3: Delete the inbox
puts "\n🚀 Proceeding with deletion of Inbox #{inbox_to_delete_id}..."

delete_url = "#{base_url}/api/v1/accounts/#{account_id}/inboxes/#{inbox_to_delete_id}"
puts "   📡 Sending DELETE request to: #{delete_url}"

delete_response = make_api_request('DELETE', delete_url, headers)

case delete_response.code.to_i
when 200..299
  puts "   ✅ SUCCESS: Inbox #{inbox_to_delete_id} deleted successfully"
  puts "      Status: #{delete_response.code} #{delete_response.message}"
  
  # Update backup with success status
  backup_info[:deletion_status] = "success"
  backup_info[:deletion_response_code] = delete_response.code.to_i
  backup_info[:deletion_response_body] = delete_response.body
  File.write(backup_file, JSON.pretty_generate(backup_info))
  
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
  backup_info[:deletion_response_code] = delete_response.code.to_i
  File.write(backup_file, JSON.pretty_generate(backup_info))
  
when 500..599
  puts "   💥 SERVER ERROR: #{delete_response.code} #{delete_response.message}"
  if delete_response.body
    puts "      Response: #{delete_response.body[0..200]}"
  end
  
  backup_info[:deletion_status] = "server_error"
  backup_info[:deletion_error] = delete_response.body
  backup_info[:deletion_response_code] = delete_response.code.to_i
  File.write(backup_file, JSON.pretty_generate(backup_info))
  
else
  puts "   ⚠️  UNEXPECTED RESPONSE: #{delete_response.code} #{delete_response.message}"
  backup_info[:deletion_status] = "unexpected"
  backup_info[:deletion_error] = delete_response.body
  backup_info[:deletion_response_code] = delete_response.code.to_i
  File.write(backup_file, JSON.pretty_generate(backup_info))
end

# Step 4: Verify deletion
puts "\n🔍 Verifying deletion..."

verify_response = make_api_request('GET', delete_url, headers)

if verify_response.code.to_i == 404
  puts "   ✅ Confirmed: Inbox #{inbox_to_delete_id} no longer exists"
  backup_info[:verification_status] = "confirmed_deleted"
elsif verify_response.code.to_i == 200
  puts "   ⚠️  Warning: Inbox #{inbox_to_delete_id} still exists!"
  backup_info[:verification_status] = "still_exists"
else
  puts "   ⚠️  Verification inconclusive: #{verify_response.code}"
  backup_info[:verification_status] = "inconclusive"
end

# Step 5: Final check - list all remaining inboxes
puts "\n📊 Final verification - checking remaining inboxes..."

inboxes_url = "#{base_url}/api/v1/accounts/#{account_id}/inboxes"
final_response = make_api_request('GET', inboxes_url, headers)

if final_response.code.to_i == 200
  begin
    parsed_response = JSON.parse(final_response.body)
    inboxes = parsed_response['payload'] || parsed_response
    
    remaining_sms_inboxes = inboxes.select do |inbox|
      inbox['channel_type'] == 'Channel::Sms' && 
      (inbox['phone_number'] == '19795412927' || inbox['phone_number'] == '+19795412927')
    end
    
    puts "   📱 Remaining SMS inboxes with target phone number: #{remaining_sms_inboxes.length}"
    remaining_sms_inboxes.each do |inbox|
      puts "      - Inbox #{inbox['id']}: #{inbox['name']} (#{inbox['phone_number']})"
    end
    
    if remaining_sms_inboxes.length == 1
      puts "   ✅ SUCCESS: Duplicate resolved! Only one SMS inbox remains."
      puts "      Remaining: Inbox #{remaining_sms_inboxes.first['id']} with #{remaining_sms_inboxes.first['phone_number']}"
    elsif remaining_sms_inboxes.length == 0
      puts "   ⚠️  WARNING: No SMS inboxes remain with this phone number!"
    else
      puts "   ⚠️  WARNING: Multiple SMS inboxes still exist!"
    end
    
    backup_info[:final_verification] = {
      remaining_sms_inboxes_count: remaining_sms_inboxes.length,
      remaining_inboxes: remaining_sms_inboxes
    }
    
  rescue JSON::ParserError
    puts "   ⚠️  Could not parse final verification response"
    backup_info[:final_verification] = "parse_error"
  end
end

# Update final backup file
File.write(backup_file, JSON.pretty_generate(backup_info))

puts "\n✨ Inbox deletion process completed!"
puts "   📄 Complete backup: #{backup_file}"

if backup_info[:deletion_status] == "success" && backup_info[:verification_status] == "confirmed_deleted"
  puts "   🎉 SUCCESS: Duplicate inbox successfully removed!"
else
  puts "   ⚠️  Check backup file for detailed results"
end 