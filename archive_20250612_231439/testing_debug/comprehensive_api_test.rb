#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'
require 'pg'
require 'securerandom'

puts "🚀 COMPREHENSIVE CHATWOOT API TEST PROCESS"
puts "=" * 80

# Configuration
API_BASE = "https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
GATEWAY_BASE = "https://voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io"

# Database configuration
DB_CONFIG = {
  host: 'chatwoot-db-fresh.postgres.database.azure.com',
  port: 5432,
  dbname: 'chatwoot_production',
  user: 'chatwootuser',
  password: 'chatwoot123'
}

# Global variables for test data
$platform_token = nil
$platform_app_id = nil
$account_id = nil
$test_user_id = nil
$test_user_email = nil
$test_user_token = nil  # NEW: User API token for operational activities
$test_inbox_id = nil
$twilio_inbox_id = nil
$conversation_id = nil
$message_id = nil
$test_phone = "4353397687"

# Results tracking
$results = []
$successes = 0
$errors = 0
$info_messages = 0

def log_result(type, message)
  $results << { type: type, message: message }
  case type
  when :success
    puts "✅ #{message}"
    $successes += 1
  when :error
    puts "❌ #{message}"
    $errors += 1
  when :info
    puts "ℹ️  #{message}"
    $info_messages += 1
  end
end

def log_step(step_number, description)
  puts "\n#{step_number} #{description}..."
end

def make_api_call(method, url, headers = {}, body = nil)
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  
  request = case method.upcase
  when 'GET'
    Net::HTTP::Get.new(uri)
  when 'POST'
    Net::HTTP::Post.new(uri)
  when 'PUT'
    Net::HTTP::Put.new(uri)
  when 'DELETE'
    Net::HTTP::Delete.new(uri)
  end
  
  headers.each { |key, value| request[key] = value }
  request.body = body if body
  
  puts "📡 API Call: #{method} #{url}"
  response = http.request(request)
  puts "📊 Response Code: #{response.code}"
  
  log_result(:success, "API call successful") if response.code.to_i < 400
  log_result(:error, "API call failed: #{response.body}") if response.code.to_i >= 400
  
  response
rescue => e
  log_result(:error, "API call exception: #{e.message}")
  nil
end

def make_webhook_call(url, form_data)
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  
  request = Net::HTTP::Post.new(uri)
  request.set_form_data(form_data)
  
  puts "📡 Twilio Webhook: POST #{url}"
  response = http.request(request)
  puts "📊 Response Code: #{response.code}"
  
  log_result(:success, "Twilio callback simulation successful") if response.code.to_i < 400
  log_result(:error, "Twilio callback failed: #{response.body}") if response.code.to_i >= 400
  
  response
rescue => e
  log_result(:error, "Webhook call exception: #{e.message}")
  nil
end

def connect_to_database
  log_step("🔌 STEP 1:", "Connecting to Database")
  
  begin
    $db_connection = PG.connect(DB_CONFIG)
    log_result(:success, "Database connection established")
    return true
  rescue => e
    log_result(:error, "Database connection failed: #{e.message}")
    return false
  end
end

def get_platform_token
  log_step("🔑 STEP 2:", "Getting Platform Token")
  
  begin
    # Check for existing platform app
    result = $db_connection.exec("
      SELECT pa.id, at.token 
      FROM platform_apps pa 
      JOIN access_tokens at ON at.owner_id = pa.id AND at.owner_type = 'PlatformApp'
      LIMIT 1
    ")
    
    log_result(:success, "Finding existing platform app - #{result.ntuples} rows returned")
    
    if result.ntuples > 0
      $platform_app_id = result[0]['id'].to_i
      $platform_token = result[0]['token']
      log_result(:success, "Found existing platform token: #{$platform_token[0..20]}...")
      return true
    else
      log_result(:error, "No platform app found in database")
      return false
    end
  rescue => e
    log_result(:error, "Database query failed: #{e.message}")
    return false
  end
end

def setup_platform_permissions
  puts "\n🔧 Checking and fixing platform app permissions..."
  
  begin
    # Check existing permissions
    result = $db_connection.exec("
      SELECT permissible_type, permissible_id 
      FROM platform_app_permissibles 
      WHERE platform_app_id = #{$platform_app_id}
    ")
    
    log_result(:success, "Checking existing permissions - #{result.ntuples} rows returned")
    log_result(:success, "Found #{result.ntuples} existing permission(s)")
    
    result.each do |row|
      if row['permissible_type'] == 'Account'
        log_result(:info, "Permission: Account ID #{row['permissible_id']}")
      elsif row['permissible_type'] == 'User'
        log_result(:info, "Permission: User ID #{row['permissible_id']}")
      end
    end
    
    if $account_id
      log_result(:info, "Setting up platform app permissions for account #{$account_id}...")
      
      # Check if account permission exists
      account_check = $db_connection.exec("
        SELECT id FROM platform_app_permissibles 
        WHERE platform_app_id = #{$platform_app_id} 
        AND permissible_type = 'Account' 
        AND permissible_id = #{$account_id}
      ")
      
      log_result(:success, "Checking account permission - #{account_check.ntuples} rows returned")
      
      if account_check.ntuples == 0
        # Add account permission
        $db_connection.exec("
          INSERT INTO platform_app_permissibles (platform_app_id, permissible_type, permissible_id, created_at, updated_at)
          VALUES (#{$platform_app_id}, 'Account', #{$account_id}, NOW(), NOW())
        ")
        log_result(:success, "Added account permission for account #{$account_id}")
      else
        log_result(:success, "Account permission already exists")
      end
    else
      log_result(:info, "Account ID not available yet, will set permissions later")
    end
    
    # Verify final permissions
    final_result = $db_connection.exec("
      SELECT COUNT(*) as count 
      FROM platform_app_permissibles 
      WHERE platform_app_id = #{$platform_app_id}
    ")
    
    log_result(:success, "Verifying final permissions - #{final_result.ntuples} rows returned")
    log_result(:success, "Platform app has #{final_result[0]['count']} permission(s)")
    
    return true
  rescue => e
    log_result(:error, "Permission setup failed: #{e.message}")
    return false
  end
end

def find_voicelinkai_account
  log_step("🏢 STEP 3:", "Finding VoiceLinkAI Account")
  
  begin
    result = $db_connection.exec("
      SELECT id, name 
      FROM accounts 
      WHERE name LIKE '%voicelinkai%' 
      LIMIT 1
    ")
    
    log_result(:success, "Finding VoiceLinkAI account - #{result.ntuples} rows returned")
    
    if result.ntuples > 0
      $account_id = result[0]['id'].to_i
      account_name = result[0]['name']
      log_result(:success, "Found account: #{account_name} (ID: #{$account_id})")
      
      # Now set up permissions for this account
      setup_platform_permissions
      
      return true
    else
      log_result(:error, "VoiceLinkAI account not found")
      return false
    end
  rescue => e
    log_result(:error, "Database query failed: #{e.message}")
    return false
  end
end

def create_test_user
  log_step("👤 STEP 4:", "Creating Test User")
  
  begin
    # Generate unique email
    unique_id = SecureRandom.hex(4)
    $test_user_email = "testuser_#{unique_id}@voicelinkai.com"
    
    # Create user via Platform API (using platform token)
    user_data = {
      name: "Test User #{unique_id}",
      email: $test_user_email,
      password: "TestPassword123!"
    }
    
    headers = {
      'Content-Type' => 'application/json',
      'api_access_token' => $platform_token
    }
    
    response = make_api_call(
      'POST',
      "#{API_BASE}/platform/api/v1/users",
      headers,
      user_data.to_json
    )
    
    if response && response.code.to_i < 400
      user_info = JSON.parse(response.body)
      $test_user_id = user_info['id']
      log_result(:success, "Created test user: #{user_info['name']} (ID: #{$test_user_id})")
      
      # Add user to account as ADMINISTRATOR (not agent)
      account_user_data = {
        user_id: $test_user_id,
        role: "administrator"  # CHANGED: Use administrator role for inbox management
      }
      
      response = make_api_call(
        'POST',
        "#{API_BASE}/platform/api/v1/accounts/#{$account_id}/account_users",
        headers,
        account_user_data.to_json
      )
      
      if response && response.code.to_i < 400
        log_result(:success, "Added user to account #{$account_id} as administrator")
        return true
      else
        log_result(:error, "Failed to add user to account: #{response&.body}")
        return false
      end
    else
      log_result(:error, "Failed to create user: #{response&.body}")
      return false
    end
  rescue => e
    log_result(:error, "User creation failed: #{e.message}")
    return false
  end
end

def get_user_api_token
  log_step("🔑 STEP 5:", "Getting User API Token")
  
  begin
    # Get the user's API token from database
    result = $db_connection.exec("
      SELECT at.token 
      FROM access_tokens at 
      JOIN users u ON u.id = at.owner_id 
      WHERE at.owner_type = 'User' 
      AND u.email = '#{$test_user_email}'
      LIMIT 1
    ")
    
    log_result(:success, "Finding user API token - #{result.ntuples} rows returned")
    
    if result.ntuples > 0
      $test_user_token = result[0]['token']
      log_result(:success, "Found user API token: #{$test_user_token[0..20]}...")
      return true
    else
      log_result(:error, "User API token not found for #{$test_user_email}")
      return false
    end
  rescue => e
    log_result(:error, "Token lookup failed: #{e.message}")
    return false
  end
end

def create_test_inbox
  log_step("📥 STEP 6:", "Creating Test Inbox")
  
  begin
    # Use USER token for inbox operations (not platform token)
    inbox_data = {
      name: "Test Inbox #{SecureRandom.hex(4)}",
      channel: {
        type: "web_widget",
        website_url: "https://test.voicelinkai.com"
      }
    }
    
    headers = {
      'Content-Type' => 'application/json',
      'api_access_token' => $test_user_token  # CHANGED: Use user token
    }
    
    response = make_api_call(
      'POST',
      "#{API_BASE}/api/v1/accounts/#{$account_id}/inboxes",
      headers,
      inbox_data.to_json
    )
    
    if response && response.code.to_i < 400
      inbox_info = JSON.parse(response.body)
      $test_inbox_id = inbox_info['id']
      log_result(:success, "Created test inbox: #{inbox_info['name']} (ID: #{$test_inbox_id})")
      return true
    else
      log_result(:error, "Failed to create inbox: #{response&.body}")
      return false
    end
  rescue => e
    log_result(:error, "Inbox creation failed: #{e.message}")
    return false
  end
end

def assign_user_to_inbox
  log_step("🔗 STEP 7:", "Assigning User to Test Inbox")
  
  begin
    # Use USER token for inbox member operations
    assignment_data = {
      inbox_id: $test_inbox_id,
      user_ids: [$test_user_id]
    }
    
    headers = {
      'Content-Type' => 'application/json',
      'api_access_token' => $test_user_token  # CHANGED: Use user token
    }
    
    response = make_api_call(
      'POST',
      "#{API_BASE}/api/v1/accounts/#{$account_id}/inbox_members",
      headers,
      assignment_data.to_json
    )
    
    if response && response.code.to_i < 400
      log_result(:success, "Assigned user #{$test_user_id} to inbox #{$test_inbox_id}")
      return true
    else
      log_result(:error, "Failed to assign user to inbox: #{response&.body}")
      return false
    end
  rescue => e
    log_result(:error, "User assignment failed: #{e.message}")
    return false
  end
end

def delete_test_inbox
  log_step("🗑️  STEP 8:", "Deleting Test Inbox")
  
  begin
    # Use USER token for inbox operations
    headers = {
      'api_access_token' => $test_user_token  # CHANGED: Use user token
    }
    
    response = make_api_call(
      'DELETE',
      "#{API_BASE}/api/v1/accounts/#{$account_id}/inboxes/#{$test_inbox_id}",
      headers
    )
    
    if response && response.code.to_i < 400
      log_result(:success, "Deleted test inbox #{$test_inbox_id}")
      return true
    else
      log_result(:error, "Failed to delete inbox: #{response&.body}")
      return false
    end
  rescue => e
    log_result(:error, "Inbox deletion failed: #{e.message}")
    return false
  end
end

def find_twilio_inbox
  log_step("📱 STEP 9:", "Finding Twilio SMS Inbox")
  
  begin
    # FIXED: Use correct channel type - it's 'Channel::Sms' not 'Channel::TwilioSms'
    result = $db_connection.exec("
      SELECT id, name, channel_type 
      FROM inboxes 
      WHERE channel_type = 'Channel::Sms' 
      AND account_id = #{$account_id}
      AND name LIKE '%19795412927%'
      LIMIT 1
    ")
    
    log_result(:success, "Finding Twilio SMS inbox - #{result.ntuples} rows returned")
    
    if result.ntuples > 0
      $twilio_inbox_id = result[0]['id'].to_i
      inbox_name = result[0]['name']
      log_result(:success, "Found Twilio inbox: #{inbox_name} (ID: #{$twilio_inbox_id})")
      return true
    else
      log_result(:error, "Twilio SMS inbox not found")
      return false
    end
  rescue => e
    log_result(:error, "Database query failed: #{e.message}")
    return false
  end
end

def assign_user_to_twilio_inbox
  log_step("📱 STEP 10:", "Assigning User to Twilio Inbox")
  
  begin
    # Use USER token for inbox member operations
    assignment_data = {
      inbox_id: $twilio_inbox_id,
      user_ids: [$test_user_id]
    }
    
    headers = {
      'Content-Type' => 'application/json',
      'api_access_token' => $test_user_token  # CHANGED: Use user token
    }
    
    response = make_api_call(
      'POST',
      "#{API_BASE}/api/v1/accounts/#{$account_id}/inbox_members",
      headers,
      assignment_data.to_json
    )
    
    if response && response.code.to_i < 400
      log_result(:success, "Assigned user #{$test_user_id} to Twilio inbox #{$twilio_inbox_id}")
      return true
    else
      log_result(:error, "Failed to assign user to Twilio inbox: #{response&.body}")
      return false
    end
  rescue => e
    log_result(:error, "Twilio assignment failed: #{e.message}")
    return false
  end
end

def send_test_message
  log_step("💬 STEP 11:", "Sending Test Message to #{$test_phone}")
  
  begin
    # Use USER token for conversation operations
    conversation_data = {
      source_id: $test_phone,
      inbox_id: $twilio_inbox_id,
      contact_id: nil
    }
    
    headers = {
      'Content-Type' => 'application/json',
      'api_access_token' => $test_user_token  # CHANGED: Use user token
    }
    
    response = make_api_call(
      'POST',
      "#{API_BASE}/api/v1/accounts/#{$account_id}/conversations",
      headers,
      conversation_data.to_json
    )
    
    if response && response.code.to_i < 400
      conversation_info = JSON.parse(response.body)
      $conversation_id = conversation_info['id']
      log_result(:success, "Created conversation #{$conversation_id} for #{$test_phone}")
      return true
    else
      log_result(:error, "Failed to create conversation: #{response&.body}")
      return false
    end
  rescue => e
    log_result(:error, "Message sending failed: #{e.message}")
    return false
  end
end

def simulate_twilio_response
  log_step("📞 STEP 12:", "Simulating Twilio Callback Response")
  
  begin
    # Simulate incoming SMS from Twilio
    form_data = {
      'From' => "+1#{$test_phone}",
      'To' => '+19795412927',
      'Body' => 'Test message from comprehensive API test',
      'MessageSid' => "SM#{SecureRandom.hex(16)}",
      'AccountSid' => 'AC' + SecureRandom.hex(16),
      'MessagingServiceSid' => 'MG' + SecureRandom.hex(16)
    }
    
    response = make_webhook_call(
      "#{API_BASE}/webhooks/sms/19795412927",
      form_data
    )
    
    return response && response.code.to_i < 400
  rescue => e
    log_result(:error, "Twilio simulation failed: #{e.message}")
    return false
  end
end

def verify_user_can_view_messages
  log_step("👀 STEP 13:", "Verifying User Can View Messages")
  
  begin
    # Use USER token for message retrieval
    headers = {
      'api_access_token' => $test_user_token  # CHANGED: Use user token
    }
    
    response = make_api_call(
      'GET',
      "#{API_BASE}/api/v1/accounts/#{$account_id}/conversations/#{$conversation_id}/messages",
      headers
    )
    
    if response && response.code.to_i < 400
      messages = JSON.parse(response.body)
      message_count = messages.is_a?(Array) ? messages.length : (messages['payload'] || []).length
      log_result(:success, "Retrieved #{message_count} messages for conversation #{$conversation_id}")
      return true
    else
      log_result(:error, "Failed to retrieve messages: #{response&.body}")
      return false
    end
  rescue => e
    log_result(:error, "Message retrieval failed: #{e.message}")
    return false
  end
end

def cleanup
  log_step("🧹 STEP 14:", "Cleanup")
  
  begin
    # Delete test user using platform token
    if $test_user_id
      headers = {
        'api_access_token' => $platform_token  # Use platform token for user deletion
      }
      
      response = make_api_call(
        'DELETE',
        "#{API_BASE}/platform/api/v1/users/#{$test_user_id}",
        headers
      )
      
      if response && response.code.to_i < 400
        log_result(:success, "Deleted test user #{$test_user_id}")
      else
        log_result(:error, "Failed to delete test user: #{response&.body}")
      end
    end
    
    log_result(:info, "Cleanup completed")
    return true
  rescue => e
    log_result(:error, "Cleanup failed: #{e.message}")
    return false
  end
end

def print_summary
  puts "\n" + "="*80
  puts "📊 COMPREHENSIVE TEST REPORT"
  puts "="*80
  puts "📈 SUMMARY:"
  puts "   ✅ Successes: #{$successes}"
  puts "   ❌ Errors: #{$errors}"
  puts "   ℹ️  Info: #{$info_messages}"
  puts "   📊 Total: #{$results.length}"
  puts "   🎯 Success Rate: #{(($successes.to_f / ($successes + $errors)) * 100).round(1)}%"
  
  puts "\n📋 DETAILED RESULTS:"
  $results.each_with_index do |result, index|
    icon = case result[:type]
    when :success then "✅"
    when :error then "❌"
    when :info then "ℹ️"
    end
    puts "#{index + 1}. #{icon} #{result[:message]}"
  end
  
  puts "\n🔗 TEST DATA USED:"
  puts "   Account ID: #{$account_id}"
  puts "   Platform App ID: #{$platform_app_id}"
  puts "   Platform Token: #{$platform_token ? $platform_token[0..20] + '...' : 'N/A'}"
  puts "   Test User ID: #{$test_user_id}"
  puts "   Test User Email: #{$test_user_email}"
  puts "   Test User Token: #{$test_user_token ? $test_user_token[0..20] + '...' : 'N/A'}"
  puts "   Test Inbox ID: #{$test_inbox_id}"
  puts "   Twilio Inbox ID: #{$twilio_inbox_id}"
  puts "   Conversation ID: #{$conversation_id}"
  puts "   Message ID: #{$message_id}"
  puts "   Test Phone: #{$test_phone}"
end

# Main execution
def run_comprehensive_test
  puts "🚀 COMPREHENSIVE CHATWOOT API TEST PROCESS"
  puts "="*80
  
  # Execute test steps
  steps = [
    method(:connect_to_database),
    method(:get_platform_token),
    method(:find_voicelinkai_account),
    method(:create_test_user),
    method(:get_user_api_token),        # NEW STEP
    method(:create_test_inbox),
    method(:assign_user_to_inbox),
    method(:delete_test_inbox),
    method(:find_twilio_inbox),
    method(:assign_user_to_twilio_inbox),
    method(:send_test_message),
    method(:simulate_twilio_response),
    method(:verify_user_can_view_messages),
    method(:cleanup)
  ]
  
  steps.each_with_index do |step, index|
    success = step.call
    unless success
      log_result(:error, "Test failed at step: #{step.name.to_s.gsub('_', ' ')}")
      puts "\n⚠️  Continuing with remaining steps for diagnostic purposes..."
    end
  end
  
  print_summary
  
  puts "\n" + "="*80
  puts "✨ COMPREHENSIVE TEST COMPLETED!"
  puts "="*80
end

# Run the test
if __FILE__ == $0
  run_comprehensive_test
end 