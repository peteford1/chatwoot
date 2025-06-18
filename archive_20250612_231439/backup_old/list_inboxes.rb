# frozen_string_literal: true

require_relative './config/environment'

account_id = 3
account = Account.find_by(id: account_id)

if account
  puts "Inboxes for account '#{account.name}' (ID: #{account.id}):"
  if account.inboxes.any?
    account.inboxes.each do |inbox|
      puts "  ID: #{inbox.id}, Name: #{inbox.name}, Channel Type: #{inbox.channel_type}"
    end
  else
    puts "  No inboxes found for this account."
  end
else
  puts "Account with ID #{account_id} not found."
end 