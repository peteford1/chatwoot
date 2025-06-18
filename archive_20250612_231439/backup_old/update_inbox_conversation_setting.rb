#!/usr/bin/env ruby

puts "🔧 Updating Inbox Conversation Settings for Account 1..."
puts "======================================================"

# Find Account 1
account = Account.find_by(id: 1)
if account.nil?
  puts "❌ Account 1 not found!"
  exit 1
end

puts "✅ Found Account: #{account.name} (ID: #{account.id})"
puts ""

# Get all inboxes for Account 1
inboxes = account.inboxes.all

if inboxes.empty?
  puts "❌ No inboxes found for Account 1"
  exit 1
end

puts "📋 Found #{inboxes.count} inbox(es) for Account 1:"
inboxes.each do |inbox|
  puts "   • #{inbox.name} (ID: #{inbox.id}) - Current setting: #{inbox.lock_to_single_conversation}"
end

puts ""
puts "🔄 Updating lock_to_single_conversation to FALSE for all inboxes..."

# Update each inbox
updated_count = 0
inboxes.each do |inbox|
  begin
    old_setting = inbox.lock_to_single_conversation
    inbox.update!(lock_to_single_conversation: false)
    
    if old_setting != false
      puts "   ✅ Updated '#{inbox.name}' (#{inbox.channel_type}): #{old_setting} → false"
      updated_count += 1
    else
      puts "   ✓ '#{inbox.name}' already set to false"
    end
  rescue => e
    puts "   ❌ Failed to update '#{inbox.name}': #{e.message}"
  end
end

puts ""
puts "🎉 Update Complete!"
puts "   • #{updated_count} inbox(es) updated"
puts "   • #{inboxes.count - updated_count} inbox(es) were already set correctly"

puts ""
puts "📋 Final Settings:"
inboxes.reload.each do |inbox|
  puts "   • #{inbox.name}: lock_to_single_conversation = #{inbox.lock_to_single_conversation}"
end

puts ""
puts "🎯 **What This Means:**"
puts "   • New conversations will be created when previous ones are RESOLVED"
puts "   • Open/pending conversations will continue to receive new messages"
puts "   • Better organization for ticket-based support workflows"
puts "   • Each resolved issue gets its own conversation thread"

puts ""
puts "✅ SUCCESS: All inboxes now support multiple conversations per contact!" 