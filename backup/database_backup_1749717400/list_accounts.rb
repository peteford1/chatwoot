# frozen_string_literal: true

require_relative './config/environment'

puts 'Accounts in the database:'
Account.all.each do |account|
  puts "  ID: #{account.id}, Name: #{account.name}, Locale: #{account.locale}, Status: #{account.status}"
end 