#!/usr/bin/env ruby

require 'bundler/setup'
require 'rails/all'

# Load Rails environment
ENV['RAILS_ENV'] ||= 'production'
require_relative 'config/environment'

USER_EMAIL = 'admin@voicelinkai.com'

begin
  puts "🔍 Finding details for user: #{USER_EMAIL}"

  user = User.find_by('lower(email) = ?', USER_EMAIL.downcase)

  if user.nil?
    puts "❌ User not found."
    exit 1
  end

  # --- Get User and Account IDs ---
  account = user.accounts.first
  if account.nil?
    puts "❌ User is not associated with any account."
    exit 1
  end

  user_id = user.id
  account_id = account.id

  # --- Get API Access Token ---
  # The AccessTokenable concern ensures a token is created for the user.
  access_token = user.access_token

  if access_token.nil?
    puts "🤔 Access token not found. Creating a new one..."
    access_token = user.create_access_token
    puts "✅ New access token created."
  end
  
  api_token = access_token.token

  # --- Display Information ---
  puts "\n🎉 Found user details:"
  puts "----------------------------------"
  puts "  User ID:      #{user_id}"
  puts "  Account ID:   #{account_id}"
  puts "  API Token:    #{api_token}"
  puts "----------------------------------"

rescue StandardError => e
  puts "❌ An error occurred: #{e.message}"
  puts e.backtrace
  exit 1
end 