#!/usr/bin/env ruby

require 'bundler/setup'
require 'rails/all'

# Load Rails environment
ENV['RAILS_ENV'] ||= 'production'
require_relative 'config/environment'

ADMIN_EMAIL = 'admin@voicelinkai.com'
ADMIN_PASSWORD = 'Password123!'

begin
  # --- 1. Find or create the Account ---
  account = Account.find_by(name: 'Default Account')
  if account.nil?
    puts "🤔 No default account found. Creating one..."
    account = Account.create!(name: 'Default Account', locale: 'en')
    puts "✅ Created account: #{account.name} (ID: #{account.id})"
  else
    puts "✅ Using existing account: #{account.name} (ID: #{account.id})"
  end

  # --- 2. Find or create the User ---
  user = User.find_by(email: ADMIN_EMAIL)
  if user.nil?
    puts "🚀 Creating new user..."
    user = User.create!(
      email: ADMIN_EMAIL,
      name: 'Store Admin',
      password: ADMIN_PASSWORD,
      password_confirmation: ADMIN_PASSWORD,
      confirmed_at: Time.current # Auto-confirm user
    )
    puts "✅ User created successfully: #{user.email}"
  else
    puts "✅ User '#{user.email}' already exists."
  end

  # --- 3. Find or create the AccountUser link with admin role ---
  account_user = AccountUser.find_by(account_id: account.id, user_id: user.id)
  if account_user.nil?
    puts "🔗 Linking user to account as administrator..."
    AccountUser.create!(account: account, user: user, role: :administrator)
    puts "✅ User linked successfully."
  elsif !account_user.administrator?
    puts "🔧 User is not an administrator. Updating role..."
    account_user.update!(role: :administrator)
    puts "✅ User role updated."
  else
    puts "✅ User is already an administrator for the account."
  end

  puts "\nRetrieving user details..."
  user_details = User.find_by(email: ADMIN_EMAIL)
  if user_details
    account_details = user_details.accounts.first
    token_details = user_details.access_token

    puts "----------------------------------"
    puts "  User ID:      #{user_details.id}"
    puts "  Account ID:   #{account_details&.id || 'Not Found'}"
    puts "  API Token:    #{token_details&.token || 'Not Found'}"
    puts "----------------------------------"
  else
      puts "❌ Could not retrieve details for user #{ADMIN_EMAIL}"
  end

  puts "\n🎉 Setup complete!"
  puts "You can now log in at https://voicelinkai.com/app/login with:"
  puts "  Email:    #{ADMIN_EMAIL}"
  puts "  Password: #{ADMIN_PASSWORD}"

rescue StandardError => e
  puts "❌ An error occurred: #{e.message}"
  puts e.backtrace
  exit 1
end 