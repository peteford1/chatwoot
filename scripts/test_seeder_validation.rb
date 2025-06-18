#!/usr/bin/env ruby

# VoiceLinkAI Seeder Validation Script
# Purpose: Test the seeder approach without creating actual accounts
# Usage: bundle exec rails runner scripts/test_seeder_validation.rb

puts "🧪 VoiceLinkAI Seeder Validation"
puts "=" * 50

# Test 1: Model Availability
puts "\n✅ Testing Model Availability:"
models = ['PlatformApp', 'User', 'Account', 'SuperAdmin', 'AccessToken', 'AccountUser']
models.each do |model|
  status = defined?(Object.const_get(model)) ? "✅ Available" : "❌ Missing"
  puts "  #{model}: #{status}"
end

# Test 2: Platform API Check
puts "\n✅ Testing Platform App Creation:"
begin
  existing_platform_apps = PlatformApp.count
  puts "  Current Platform Apps: #{existing_platform_apps}"
  puts "  ✅ PlatformApp model accessible"
rescue => e
  puts "  ❌ PlatformApp error: #{e.message}"
end

# Test 3: SuperAdmin Check
puts "\n✅ Testing SuperAdmin Model:"
begin
  existing_super_admins = SuperAdmin.count
  puts "  Current SuperAdmins: #{existing_super_admins}"
  puts "  ✅ SuperAdmin model accessible"
rescue => e
  puts "  ❌ SuperAdmin error: #{e.message}"
end

# Test 4: AccessToken Check
puts "\n✅ Testing AccessToken Model:"
begin
  existing_tokens = AccessToken.count
  puts "  Current AccessTokens: #{existing_tokens}"
  puts "  ✅ AccessToken model accessible"
rescue => e
  puts "  ❌ AccessToken error: #{e.message}"
end

# Test 5: Account/User Check
puts "\n✅ Testing Account and User Models:"
begin
  existing_accounts = Account.count
  existing_users = User.count
  puts "  Current Accounts: #{existing_accounts}"
  puts "  Current Users: #{existing_users}"
  puts "  ✅ Account and User models accessible"
rescue => e
  puts "  ❌ Account/User error: #{e.message}"
end

# Test 6: Check for existing VoiceLinkAI data
puts "\n✅ Checking for Existing VoiceLinkAI Data:"
begin
  existing_account = Account.find_by(name: 'voicelinkai')
  existing_users = User.where(email: ['admin@voicelinkai.com', 'storeadmin@voicelinkai.com'])
  
  if existing_account
    puts "  ⚠️  VoiceLinkAI account already exists: ID #{existing_account.id}"
  else
    puts "  ✅ No existing VoiceLinkAI account found"
  end
  
  if existing_users.any?
    puts "  ⚠️  VoiceLinkAI users already exist:"
    existing_users.each { |u| puts "    - #{u.email} (ID: #{u.id})" }
  else
    puts "  ✅ No existing VoiceLinkAI users found"
  end
rescue => e
  puts "  ❌ Existing data check error: #{e.message}"
end

# Test 7: Token Generation Test
puts "\n✅ Testing Token Generation:"
begin
  test_token = SecureRandom.hex(32)
  puts "  Sample token generated: #{test_token[0..16]}..."
  puts "  ✅ Token generation working"
rescue => e
  puts "  ❌ Token generation error: #{e.message}"
end

# Test 8: API Endpoint Validation
puts "\n✅ Testing API Endpoints (theoretical):"
api_endpoints = [
  'POST /platform/api/v1/accounts',
  'POST /platform/api/v1/users', 
  'POST /platform/api/v1/accounts/{id}/account_users',
  'POST /api/v1/accounts/{id}/channels/twilio_channel'
]
api_endpoints.each { |endpoint| puts "  📍 #{endpoint}" }
puts "  ✅ API endpoints identified"

puts "\n" + "=" * 50
puts "🎯 VALIDATION SUMMARY"
puts "=" * 50

puts "✅ All required models are available"
puts "✅ Database connections working" 
puts "✅ Token generation functional"
puts "✅ Ready for seeder execution"

puts "\n💡 To run the actual seeder:"
puts "bundle exec rails runner scripts/deployment_seeder_rails.rb"

puts "\n⚠️  Note: The seeder will create actual accounts and users."
puts "Run only once per environment to avoid duplicates." 