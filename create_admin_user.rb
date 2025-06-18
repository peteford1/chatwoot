#!/usr/bin/env ruby

require 'bundler/setup'
require 'rails/all'

# Load Rails environment
ENV['RAILS_ENV'] ||= 'production'
require_relative 'config/environment'

# Create SuperAdmin user for Chatwoot
puts "Creating SuperAdmin user..."

begin
  # Create the SuperAdmin user
  super_admin = User.create!(
    name: 'Super Administrator',
    email: 'admin@voicelinkai.com',
    password: 'SuperAdmin123!',
    password_confirmation: 'SuperAdmin123!',
    type: 'SuperAdmin',
    confirmed_at: Time.current
  )

  puts "✅ SuperAdmin user created successfully!"
  puts "   ID: #{super_admin.id}"
  puts "   Name: #{super_admin.name}"
  puts "   Email: #{super_admin.email}"
  puts "   Type: #{super_admin.type}"
  
  # Create access token
  access_token = super_admin.create_access_token
  puts "   Access Token: #{access_token.token}"

  puts "\n🔐 Login Details:"
  puts "   URL: https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/super_admin"
  puts "   Email: admin@voicelinkai.com"
  puts "   Password: SuperAdmin123!"

rescue => e
  puts "❌ Error creating SuperAdmin user: #{e.message}"
  puts "   #{e.backtrace.first}"
end 