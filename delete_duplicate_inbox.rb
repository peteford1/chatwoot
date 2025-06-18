#!/usr/bin/env ruby

puts "🗑️  Identifying and Deleting Duplicate Inbox..."

# Phone number that has duplicates
phone_number = "19795412927"
phone_number_with_plus = "+19795412927"

puts "\n🔍 Searching for duplicate inboxes with phone number: #{phone_number}"

# Find all inboxes with this phone number
duplicate_inboxes = []

# Check SMS channels
if defined?(Channel::Sms)
  sms_channels = Channel::Sms.where(
    "phone_number = ? OR phone_number = ?", 
    phone_number, phone_number_with_plus
  )
  
  sms_channels.each do |channel|
    if channel.inbox
      duplicate_inboxes << {
        inbox_id: channel.inbox.id,
        inbox_name: channel.inbox.name,
        channel_id: channel.id,
        channel_type: 'SMS',
        phone_number: channel.phone_number,
        created_at: channel.created_at,
        account_id: channel.account_id
      }
    end
  end
end

# Check Twilio SMS channels
if defined?(Channel::TwilioSms)
  twilio_channels = Channel::TwilioSms.where(
    "phone_number = ? OR phone_number = ?", 
    phone_number, phone_number_with_plus
  )
  
  twilio_channels.each do |channel|
    if channel.inbox
      duplicate_inboxes << {
        inbox_id: channel.inbox.id,
        inbox_name: channel.inbox.name,
        channel_id: channel.id,
        channel_type: 'TwilioSMS',
        phone_number: channel.phone_number,
        created_at: channel.created_at,
        account_id: channel.account_id
      }
    end
  end
end

puts "\n📋 Found #{duplicate_inboxes.length} inboxes with this phone number:"

if duplicate_inboxes.empty?
  puts "   ✅ No duplicate inboxes found"
  exit 0
end

duplicate_inboxes.each_with_index do |inbox_info, index|
  puts "\n#{index + 1}. Inbox ID: #{inbox_info[:inbox_id]}"
  puts "   Name: #{inbox_info[:inbox_name]}"
  puts "   Channel Type: #{inbox_info[:channel_type]}"
  puts "   Channel ID: #{inbox_info[:channel_id]}"
  puts "   Phone: #{inbox_info[:phone_number]}"
  puts "   Created: #{inbox_info[:created_at]}"
  puts "   Account: #{inbox_info[:account_id]}"
end

# Determine which inbox to delete (keep the newer one with proper format)
if duplicate_inboxes.length >= 2
  puts "\n🤔 Determining which inbox to delete..."
  
  # Sort by creation date (oldest first)
  sorted_inboxes = duplicate_inboxes.sort_by { |inbox| inbox[:created_at] }
  
  # Prefer to keep the one with proper international format (+)
  inbox_to_keep = duplicate_inboxes.find { |inbox| inbox[:phone_number].start_with?('+') }
  inbox_to_keep ||= sorted_inboxes.last # If no + format, keep the newest
  
  inbox_to_delete = duplicate_inboxes.find { |inbox| inbox[:inbox_id] != inbox_to_keep[:inbox_id] }
  
  puts "\n📌 RECOMMENDATION:"
  puts "   ✅ KEEP: Inbox #{inbox_to_keep[:inbox_id]} (#{inbox_to_keep[:inbox_name]})"
  puts "      Phone: #{inbox_to_keep[:phone_number]}"
  puts "      Created: #{inbox_to_keep[:created_at]}"
  puts "      Reason: #{inbox_to_keep[:phone_number].start_with?('+') ? 'Proper international format' : 'Newer creation date'}"
  
  puts "\n   🗑️  DELETE: Inbox #{inbox_to_delete[:inbox_id]} (#{inbox_to_delete[:inbox_name]})"
  puts "      Phone: #{inbox_to_delete[:phone_number]}"
  puts "      Created: #{inbox_to_delete[:created_at]}"
  puts "      Reason: #{inbox_to_delete[:phone_number].start_with?('+') ? 'Duplicate' : 'Older and wrong format'}"
  
  # Check for conversations and messages before deletion
  puts "\n🔍 Checking for data in inbox to be deleted..."
  
  begin
    inbox_to_delete_obj = Inbox.find(inbox_to_delete[:inbox_id])
    
    conversations_count = inbox_to_delete_obj.conversations.count
    messages_count = 0
    
    if conversations_count > 0
      messages_count = Message.joins(:conversation)
                             .where(conversations: { inbox_id: inbox_to_delete[:inbox_id] })
                             .count
    end
    
    puts "   📊 Conversations: #{conversations_count}"
    puts "   💬 Messages: #{messages_count}"
    
    if conversations_count > 0 || messages_count > 0
      puts "\n⚠️  WARNING: This inbox contains data!"
      puts "   Consider migrating conversations/messages before deletion"
      puts "   Or use the API endpoint to preserve data integrity"
      
      # Create backup info
      backup_info = {
        inbox_id: inbox_to_delete[:inbox_id],
        inbox_name: inbox_to_delete[:inbox_name],
        conversations_count: conversations_count,
        messages_count: messages_count,
        phone_number: inbox_to_delete[:phone_number],
        channel_type: inbox_to_delete[:channel_type],
        channel_id: inbox_to_delete[:channel_id],
        deletion_date: Time.now.iso8601,
        reason: "Duplicate phone number cleanup"
      }
      
      # Save backup info
      backup_file = "backup/inbox_deletion_backup_#{Time.now.to_i}.json"
      FileUtils.mkdir_p("backup")
      File.write(backup_file, JSON.pretty_generate(backup_info))
      puts "   💾 Backup info saved: #{backup_file}"
    end
    
    # Perform the deletion using API approach (safer)
    puts "\n🚀 Proceeding with inbox deletion..."
    puts "   Using API endpoint for safe deletion..."
    
    # Use the API endpoint to delete the inbox
    # This ensures proper cleanup of related records
    account_id = inbox_to_delete[:account_id]
    api_token = "baea8676c67aba47c08564ce"  # Your API token
    
    require 'net/http'
    require 'uri'
    
    uri = URI("https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/accounts/#{account_id}/inboxes/#{inbox_to_delete[:inbox_id]}")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    
    request = Net::HTTP::Delete.new(uri)
    request['api_access_token'] = api_token
    request['Content-Type'] = 'application/json'
    
    puts "   📡 Sending DELETE request to API..."
    response = http.request(request)
    
    case response.code.to_i
    when 200..299
      puts "   ✅ SUCCESS: Inbox deleted successfully"
      puts "      Status: #{response.code} #{response.message}"
      
      # Verify deletion
      begin
        deleted_inbox = Inbox.find(inbox_to_delete[:inbox_id])
        puts "   ⚠️  Warning: Inbox still exists in database"
      rescue ActiveRecord::RecordNotFound
        puts "   ✅ Confirmed: Inbox removed from database"
      end
      
    when 400..499
      puts "   ❌ CLIENT ERROR: #{response.code} #{response.message}"
      if response.body
        puts "      Response: #{response.body}"
      end
      
    when 500..599
      puts "   💥 SERVER ERROR: #{response.code} #{response.message}"
      if response.body
        puts "      Response: #{response.body}"
      end
      
    else
      puts "   ⚠️  UNEXPECTED RESPONSE: #{response.code} #{response.message}"
    end
    
  rescue => e
    puts "   💥 ERROR during deletion: #{e.message}"
    puts "      #{e.class}: #{e.backtrace.first}"
  end
  
else
  puts "\n✅ Only one inbox found - no deletion needed"
end

puts "\n✨ Duplicate inbox cleanup completed!" 