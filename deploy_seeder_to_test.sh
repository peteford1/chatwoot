#!/bin/bash

# Deploy VoiceLinkAI Test Environment Seeder
# This script uploads and executes the seeder in the test container

echo "🚀 Deploying VoiceLinkAI Test Environment Seeder"
echo "=============================================="

# Check if test container is running
echo "📋 Checking test container status..."
STATUS=$(az containerapp show --name chatwoot-backend-test --resource-group SM-Test --query "properties.runningStatus" -o tsv)
if [ "$STATUS" != "Running" ]; then
    echo "❌ Test container is not running. Status: $STATUS"
    exit 1
fi
echo "✅ Test container is running"

# Create seeder script in container
echo "📝 Creating seeder script in test container..."
cat > temp_seeder.sh << 'EOF'
#!/bin/bash
echo "🌱 Starting VoiceLinkAI Test Environment Seeder..."

# Create the seeder script inside container
cat > /tmp/voicelinkai_seeder.rb << 'RUBY_EOF'
#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'uri'

# VoiceLinkAI Test Environment Seeder (Production Ready)
# This script runs in the test environment container via direct deployment
# It creates platform app and uses API calls within the same environment

puts "🚀 VoiceLinkAI Test Environment Seeder (Production)"
puts "=" * 60
puts "Environment: #{Rails.env}"
puts "Database: #{ActiveRecord::Base.connection.current_database}"
puts "Schema: #{ENV['DATABASE_SCHEMA'] || 'default'}"
puts "Timestamp: #{Time.current}"
puts "=" * 60

# Check if we're in the test environment
unless Rails.env.test?
  puts "❌ ERROR: This script should only run in test environment"
  puts "Current environment: #{Rails.env}"
  exit 1
end

# Check if platform app already exists to avoid duplicates
existing_platform_app = PlatformApp.find_by(name: 'VoiceLinkAI Test Platform')
if existing_platform_app
  puts "⚠️  Platform app already exists, using existing one"
  platform_app = existing_platform_app
  platform_token = platform_app.access_token.token
  puts "✅ Using existing Platform App: #{platform_app.name} (ID: #{platform_app.id})"
else
  # STEP 1: Create Platform App in the test environment database
  puts "\n🔧 Step 1: Creating Platform App in Test Environment"
  
  platform_app = PlatformApp.create!(name: 'VoiceLinkAI Test Platform')
  platform_token = platform_app.access_token.token
  
  puts "✅ Platform App created: #{platform_app.name} (ID: #{platform_app.id})"
end

puts "✅ Platform Token: #{platform_token[0..16]}..."

# STEP 2: Use localhost for API calls (we're inside the container)
base_url = 'http://localhost:3000'  # Internal container address

def make_api_call(method, endpoint, data = nil, token, base_url)
  uri = URI("#{base_url}#{endpoint}")
  
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = false  # localhost doesn't use SSL
  http.read_timeout = 30
  http.open_timeout = 10
  
  case method.upcase
  when 'POST'
    request = Net::HTTP::Post.new(uri.path)
    request.body = data.to_json if data
    request['Content-Type'] = 'application/json'
  when 'GET'
    request = Net::HTTP::Get.new(uri.path)
  end
  
  request['api_access_token'] = token
  
  begin
    response = http.request(request)
    puts "   API #{method} #{endpoint}: #{response.code} #{response.message}"
    
    if response.code.to_i.between?(200, 299)
      JSON.parse(response.body) rescue response.body
    else
      puts "   Error: #{response.body[0..300]}" if response.body
      { error: response.body, status: response.code }
    end
  rescue => e
    puts "   Network Error: #{e.message}"
    { error: e.message }
  end
end

# Check if VoiceLinkAI account already exists
existing_account = Account.find_by(name: 'voicelinkai')
if existing_account
  puts "\n⚠️  VoiceLinkAI account already exists"
  account_id = existing_account.id
  puts "✅ Using existing account: ID #{account_id}"
else
  # STEP 2: Create account via Platform API
  puts "\n🏢 Step 2: Creating Account via Platform API"
  
  account_data = {
    name: 'voicelinkai',
    locale: 'en'
  }
  
  account_response = make_api_call('POST', '/platform/api/v1/accounts', account_data, platform_token, base_url)
  
  if account_response.is_a?(Hash) && account_response['id']
    account_id = account_response['id']
    puts "✅ Account created: ID #{account_id}"
  else
    puts "❌ Account creation failed: #{account_response}"
    exit 1
  end
end

# Check if admin user already exists
existing_admin = User.find_by(email: 'admin@voicelinkai.com')
if existing_admin
  puts "\n⚠️  Admin user already exists"
  admin_user_id = existing_admin.id
  admin_token = existing_admin.access_token.token
  puts "✅ Using existing admin: ID #{admin_user_id}"
  puts "✅ Admin token: #{admin_token[0..16]}..."
else
  # STEP 3: Create admin user via Platform API
  puts "\n👑 Step 3: Creating Admin User via Platform API"
  
  admin_data = {
    name: 'Root Owner',
    email: 'admin@voicelinkai.com',
    password: '123@321Qq'
  }
  
  admin_response = make_api_call('POST', '/platform/api/v1/users', admin_data, platform_token, base_url)
  
  if admin_response.is_a?(Hash) && admin_response['id']
    admin_user_id = admin_response['id']
    admin_token = admin_response['access_token']
    puts "✅ Admin user created: ID #{admin_user_id}"
    puts "✅ Admin token: #{admin_token[0..16]}..."
  else
    puts "❌ Admin user creation failed: #{admin_response}"
    exit 1
  end
end

# Check if user is already linked to account
existing_account_user = AccountUser.find_by(user_id: admin_user_id, account_id: account_id)
if existing_account_user
  puts "\n⚠️  User already linked to account"
  puts "✅ Existing role: #{existing_account_user.role}"
else
  # STEP 4: Add user to account via Platform API
  puts "\n🔗 Step 4: Adding User to Account via Platform API"
  
  account_user_data = {
    user_id: admin_user_id,
    role: 'administrator'
  }
  
  account_user_response = make_api_call('POST', "/platform/api/v1/accounts/#{account_id}/account_users", account_user_data, platform_token, base_url)
  
  if account_user_response.is_a?(Hash) && !account_user_response.key?('error')
    puts "✅ User added to account as administrator"
  else
    puts "❌ Account user creation failed: #{account_user_response}"
  end
end

# STEP 5: Test API access
puts "\n🧪 Step 5: Testing API Access"

# Test Platform API
platform_test = make_api_call('GET', "/platform/api/v1/accounts/#{account_id}", nil, platform_token, base_url)
platform_working = platform_test.is_a?(Hash) && platform_test['id']
puts "Platform API Test: #{platform_working ? '✅ Working' : '❌ Failed'}"

# Test Application API with admin token
app_test = make_api_call('GET', '/api/v1/profile', nil, admin_token, base_url)
app_working = app_test.is_a?(Hash) && app_test['id']
puts "Application API Test: #{app_working ? '✅ Working' : '❌ Failed'}"

# STEP 6: Generate summary
puts "\n🎉 Test Environment Setup Complete!"
puts "=" * 60
puts "✅ Platform App: #{platform_app.name} (ID: #{platform_app.id})"
puts "✅ Platform Token: #{platform_token[0..16]}..."
puts "✅ Account: voicelinkai (ID: #{account_id})"
puts "✅ Admin User: admin@voicelinkai.com (ID: #{admin_user_id})"
puts "✅ Admin Token: #{admin_token[0..16]}..."
puts "✅ API Tests: Platform #{platform_working ? 'OK' : 'FAIL'}, Application #{app_working ? 'OK' : 'FAIL'}"
puts "=" * 60

if platform_working && app_working
  puts "\n🎯 SUCCESS: Test environment is ready for VoiceLinkAI integration!"
  puts "\n📋 Integration Details:"
  puts "CHATWOOT_URL: https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
  puts "ACCOUNT_ID: #{account_id}"
  puts "PLATFORM_TOKEN: #{platform_token}"
  puts "ADMIN_TOKEN: #{admin_token}"
  puts "\n🔐 Security: All tokens are test-environment specific with schema isolation"
else
  puts "\n❌ FAILED: API tests did not pass. Check logs above for errors."
  exit 1
end
RUBY_EOF

# Execute the seeder using Rails runner
echo "🏃 Executing seeder in Rails environment..."
cd /app && bundle exec rails runner /tmp/voicelinkai_seeder.rb

echo "🎯 Seeder execution completed!"
EOF

# Make temp script executable
chmod +x temp_seeder.sh

# Upload and execute script in container
echo "🚀 Uploading and executing seeder..."
cat temp_seeder.sh | az containerapp exec --name chatwoot-backend-test --resource-group SM-Test --command "/bin/bash"

# Clean up
rm temp_seeder.sh

echo "✅ Deployment completed!" 