puts '🗄️ DIRECT DATABASE CLEANUP'
puts '=' * 50
puts 'This script will generate Rails console commands to run manually'
puts '=' * 50

puts "\n# Step 1: Delete all messages"
puts "Message.destroy_all"

puts "\n# Step 2: Delete all conversations" 
puts "Conversation.destroy_all"

puts "\n# Step 3: Delete all contacts"
puts "Contact.destroy_all"

puts "\n# Step 4: Delete all inboxes except ID 6"
puts "Inbox.where.not(id: 6).destroy_all"

puts "\n# Step 5: Verify only inbox 6 remains"
puts "Inbox.all.pluck(:id, :name, :phone_number)"

puts "\n# Step 6: Check for any remaining dependencies"
puts "puts \"Messages: #{Message.count}\""
puts "puts \"Conversations: #{Conversation.count}\""
puts "puts \"Contacts: #{Contact.count}\""
puts "puts \"Inboxes: #{Inbox.count}\""

puts "\n" + "=" * 50
puts "Copy and paste these commands into the Rails console:"
puts "docker exec -it <container_name> rails console"
puts "Or connect to the Azure container and run: rails console"
puts "=" * 50 