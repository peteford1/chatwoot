#!/usr/bin/env ruby

# Retry the failed SMS message
# Run with: bundle exec rails runner retry_failed_message.rb

puts "🔄 Retrying failed SMS message..."

# Find the failed message
failed_message = Message.find(11)

puts "Found failed message:"
puts "  ID: #{failed_message.id}"
puts "  Content: #{failed_message.content}"
puts "  Status: #{failed_message.status}"
puts "  External Error: #{failed_message.external_error}"
puts ""

# Reset the message status and clear errors
failed_message.update!(
  status: :sent,
  external_error: nil
)

puts "✅ Message status reset to 'sent'"
puts "🚀 Triggering SendReplyJob..."

# Trigger the SendReplyJob again
SendReplyJob.perform_later(failed_message.id)

puts "✅ SendReplyJob queued!"
puts ""
puts "Check the Rails logs to see the result."
puts "If using mock mode, you should see the mock SMS output."
puts "If using real credentials, the SMS should be sent to +14353397687." 