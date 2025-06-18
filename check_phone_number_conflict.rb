#!/usr/bin/env ruby

puts "🔍 Checking Phone Number Conflicts..."

# Check for phone number conflicts across all channel types
phone_number = "+19795412927"
alt_phone_number = "19795412927"

puts "\n📱 Searching for phone number: #{phone_number}"
puts "📱 Also checking variant: #{alt_phone_number}"

# Check Twilio SMS channels
puts "\n🔍 Twilio SMS Channels:"
if defined?(Channel::TwilioSms)
  twilio_channels = Channel::TwilioSms.where(
    "phone_number = ? OR phone_number = ?", 
    phone_number, alt_phone_number
  )
  
  if twilio_channels.any?
    twilio_channels.each do |channel|
      puts "   📞 Twilio Channel ID: #{channel.id}"
      puts "      Phone: #{channel.phone_number}"
      puts "      Account ID: #{channel.account_id}"
      puts "      Inbox ID: #{channel.inbox&.id}"
      puts "      Created: #{channel.created_at}"
    end
  else
    puts "   ✅ No Twilio channels found"
  end
else
  puts "   ⚠️  TwilioSms model not available"
end

# Check SMS channels
puts "\n🔍 SMS Channels:"
if defined?(Channel::Sms)
  sms_channels = Channel::Sms.where(
    "phone_number = ? OR phone_number = ?", 
    phone_number, alt_phone_number
  )
  
  if sms_channels.any?
    sms_channels.each do |channel|
      puts "   📞 SMS Channel ID: #{channel.id}"
      puts "      Phone: #{channel.phone_number}"
      puts "      Account ID: #{channel.account_id}"
      puts "      Inbox ID: #{channel.inbox&.id}"
      puts "      Created: #{channel.created_at}"
    end
  else
    puts "   ✅ No SMS channels found"
  end
else
  puts "   ⚠️  SMS model not available"
end

# Check WhatsApp channels
puts "\n🔍 WhatsApp Channels:"
if defined?(Channel::Whatsapp)
  whatsapp_channels = Channel::Whatsapp.where(
    "phone_number = ? OR phone_number = ?", 
    phone_number, alt_phone_number
  )
  
  if whatsapp_channels.any?
    whatsapp_channels.each do |channel|
      puts "   📞 WhatsApp Channel ID: #{channel.id}"
      puts "      Phone: #{channel.phone_number}"
      puts "      Account ID: #{channel.account_id}"
      puts "      Inbox ID: #{channel.inbox&.id}"
      puts "      Created: #{channel.created_at}"
    end
  else
    puts "   ✅ No WhatsApp channels found"
  end
else
  puts "   ⚠️  WhatsApp model not available"
end

# Check which inbox we're trying to update
puts "\n🔍 Target Inbox (ID: 2):"
begin
  inbox = Inbox.find(2)
  puts "   📥 Inbox Name: #{inbox.name}"
  puts "   📥 Channel Type: #{inbox.channel_type}"
  puts "   📥 Channel ID: #{inbox.channel_id}"
  
  if inbox.channel
    puts "   📥 Current Phone: #{inbox.channel.try(:phone_number)}"
    puts "   📥 Channel Class: #{inbox.channel.class}"
  end
rescue => e
  puts "   ❌ Error finding inbox: #{e.message}"
end

puts "\n💡 RECOMMENDATIONS:"
puts "1. If duplicate phone numbers exist, remove the unused one"
puts "2. If updating existing channel, don't change phone_number"
puts "3. Check if inbox 2 is the correct channel type for Twilio"

puts "\n✨ Phone number conflict check completed!" 