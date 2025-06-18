require 'net/http'
require 'json'
require 'uri'

base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
token = 'baea8676c67aba47c08564ce'

puts '📊 CHATWOOT SYSTEM OVERVIEW'
puts '=' * 50

http = Net::HTTP.new(URI(base_url).host, URI(base_url).port)
http.use_ssl = true

# 1. Check Users
puts "\n👥 USERS IN SYSTEM:"
puts "-" * 30

uri = URI("#{base_url}/api/v1/accounts/1/agents")
request = Net::HTTP::Get.new(uri)
request['api_access_token'] = token

response = http.request(request)
if response.code == '200'
  data = JSON.parse(response.body)
  # Handle different possible data structures
  users = data.is_a?(Array) ? data : (data['payload'] || data['data'] || [])
  
  puts "Total Users: #{users.length}"
  
  users.each_with_index do |user, index|
    puts "\n#{index + 1}. #{user['name']} (#{user['email']})"
    puts "   Role: #{user['role'] || 'agent'}"
    puts "   Status: #{user['availability_status'] || 'unknown'}"
    puts "   Confirmed: #{user['confirmed'] ? '✅' : '❌'}"
    puts "   ID: #{user['id']}"
  end
else
  puts "❌ Error getting users: #{response.code}"
  puts "Response: #{response.body[0..200]}..."
end

# 2. Check Inboxes
puts "\n\n📥 INBOXES IN SYSTEM:"
puts "-" * 30

uri = URI("#{base_url}/api/v1/accounts/1/inboxes")
request = Net::HTTP::Get.new(uri)
request['api_access_token'] = token

response = http.request(request)
if response.code == '200'
  data = JSON.parse(response.body)
  # Handle different possible data structures
  inboxes = data.is_a?(Array) ? data : (data['payload'] || data['data'] || [])
  
  puts "Total Inboxes: #{inboxes.length}"
  
  inboxes.each_with_index do |inbox, index|
    status_icon = case inbox['id']
    when 2 then "🔴 STUCK"
    when 6 then "🟢 ACTIVE"
    else "📥"
    end
    
    puts "\n#{index + 1}. #{status_icon} #{inbox['name']}"
    puts "   ID: #{inbox['id']}"
    puts "   Channel: #{inbox['channel_type'] || 'Unknown'}"
    puts "   Phone: #{inbox['phone_number'] || 'N/A'}"
  end
else
  puts "❌ Error getting inboxes: #{response.code}"
  puts "Response: #{response.body[0..200]}..."
end

# 3. Check Inbox Assignments
puts "\n\n🔗 INBOX ASSIGNMENTS:"
puts "-" * 30

if response.code == '200' && defined?(inboxes)
  inboxes.each do |inbox|
    puts "\n📥 #{inbox['name']} (ID: #{inbox['id']}):"
    
    # Try to get inbox members
    members_uri = URI("#{base_url}/api/v1/accounts/1/inboxes/#{inbox['id']}/inbox_members")
    members_request = Net::HTTP::Get.new(members_uri)
    members_request['api_access_token'] = token
    
    members_response = http.request(members_request)
    if members_response.code == '200'
      members_data = JSON.parse(members_response.body)
      members = members_data.is_a?(Array) ? members_data : (members_data['payload'] || members_data['data'] || [])
      
      if members.length > 0
        puts "   👥 Assigned Users (#{members.length}):"
        members.each do |member|
          user_name = member['user'] ? member['user']['name'] : "User ID #{member['user_id']}"
          puts "     - #{user_name}"
        end
      else
        puts "   ⚠️  No users assigned"
      end
    else
      puts "   ❌ Cannot check assignments (#{members_response.code})"
    end
  end
end

# 4. Summary
puts "\n\n📋 SUMMARY:"
puts "=" * 30

if defined?(users) && defined?(inboxes)
  puts "👥 Total Users: #{users.length}"
  puts "📥 Total Inboxes: #{inboxes.length}"
  
  # Count confirmed vs unconfirmed users
  confirmed_users = users.count { |u| u['confirmed'] }
  puts "✅ Confirmed Users: #{confirmed_users}"
  puts "❌ Unconfirmed Users: #{users.length - confirmed_users}"
  
  # Identify problematic inboxes
  sms_inboxes = inboxes.select { |i| i['name']&.include?('+19795412927') }
  puts "📱 SMS Inboxes with +19795412927: #{sms_inboxes.length}"
  
  if sms_inboxes.length > 1
    puts "⚠️  DUPLICATE PHONE NUMBER DETECTED!"
    sms_inboxes.each do |inbox|
      status = inbox['id'] == 2 ? "STUCK/CORRUPTED" : "ACTIVE"
      puts "   - ID #{inbox['id']}: #{inbox['name']} (#{status})"
    end
  end
  
  # Check for unassigned inboxes
  puts "\n🔍 POTENTIAL ISSUES:"
  if users.length == 0
    puts "❌ No users in system!"
  elsif inboxes.length == 0
    puts "❌ No inboxes in system!"
  else
    puts "✅ System has both users and inboxes"
  end
  
  if sms_inboxes.length > 1
    puts "⚠️  Multiple SMS inboxes with same phone number"
  end
  
  if confirmed_users < users.length
    puts "⚠️  Some users are unconfirmed (email confirmation issue)"
  end
else
  puts "❌ Could not generate complete summary due to API errors"
end 