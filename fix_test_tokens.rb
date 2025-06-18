#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

TEST_URL = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'

puts "🔧 FIXING TOKEN ISSUE FOR TEST ENVIRONMENT"
puts "=" * 60
puts "Problem: Token exists in development DB, test uses production DB"
puts "Solution: Create user+token in production DB (via test environment)"
puts "=" * 60

# Try different approaches to create the user

# Approach 1: Check if there are any existing super admin users we can use
puts "\n📋 Step 1: Check for existing admin users..."

# Try to access the super admin panel 
uri = URI("#{TEST_URL}/super_admin")
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

response = http.get(uri.path)
puts "Super admin panel: #{response.code} #{response.message}"

# Approach 2: Try to create via onboarding (even if redirects)
puts "\n📋 Step 2: Try onboarding POST..."
onboard_uri = URI("#{TEST_URL}/installation/onboarding")

onboard_data = {
  user: {
    name: "Root Owner",
    email: "admin@voicelinkai.com", 
    password: "123@321Qq",
    password_confirmation: "123@321Qq"
  },
  account_name: "voicelinkai"
}

response = http.post(onboard_uri.path, onboard_data.to_json, {
  'Content-Type' => 'application/json'
})

puts "Onboarding POST: #{response.code} #{response.message}"
puts "Response: #{response.body[0..200]}..." if response.body

# Approach 3: Check what's in the database by examining account endpoint without auth
puts "\n📋 Step 3: Probe for existing data..."
accounts_uri = URI("#{TEST_URL}/api/v1/accounts")
response = http.get(accounts_uri.path)
puts "Accounts endpoint: #{response.code} #{response.message}"

# SOLUTION: Show the user what needs to be done
puts "\n🎯 SOLUTION - MANUAL STEPS REQUIRED:"
puts "=" * 50
puts "1. The test environment is using the PRODUCTION database"
puts "2. We need to create the admin@voicelinkai.com user in that database"
puts "3. Here are the options:"
puts ""
puts "Option A - Reset test to use development database:"
puts "   ruby scripts/manage_environments.rb --fix-database development"
puts ""
puts "Option B - Create user in production database:"
puts "   1. Access test container directly"
puts "   2. Run: bundle exec rails console"
puts "   3. Create user manually"
puts ""
puts "Option C - Use existing super admin (if any):"
puts "   1. Find existing admin in production DB"
puts "   2. Generate new token for that user"
puts ""

# Let's try to get some debugging info
puts "\n🔍 DEBUGGING INFO:"
puts "Test URL: #{TEST_URL}"
puts "Expected token: EUizDB3ETeQRF3gRYQ1j4gxi"
puts "Expected user: admin@voicelinkai.com" 
puts ""
puts "To fix immediately:"
puts "1. Run: ruby scripts/deployment_seeder_final.rb"
puts "2. But TARGET the production database used by test" 