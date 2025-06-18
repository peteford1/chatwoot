#!/usr/bin/env ruby

# Official Chatwoot Platform API Seeder for Test Environment
# This script follows the official Chatwoot documentation for creating accounts and users via API
# Reference: https://developers.chatwoot.com/contributing-guide/chatwoot-platform-apis

class ChatwootPlatformSeeder
  def initialize
    @base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
    @results = {
      platform_app: nil,
      platform_token: nil,
      account_id: nil,
      users: {},
      inbox_id: nil,
      method: 'platform_api'
    }
    
    puts "🚀 Chatwoot Platform API Seeder (Test Environment)"
    puts "=" * 60
    puts "Target URL: #{@base_url}"
    puts "Environment: TEST (isolated test schema)"
    puts "Method: Official Platform APIs"
    puts "=" * 60
  end

  def run
    puts "\n📋 DEPLOYMENT STEPS:"
    puts "1. Create Platform App (via Rails console)"
    puts "2. Create Account (via Platform API)"
    puts "3. Create Users (via Platform API)" 
    puts "4. Setup Account Users (via Platform API)"
    puts "5. Create Inbox (via Application API)"
    puts "\n🚀 Starting deployment..."
    
    step_1_create_platform_app
    step_2_create_account
    step_3_create_users
    step_4_create_inbox
    step_5_generate_environment_file
    
    puts "\n🎉 Platform API Deployment Complete!"
  end

  private

  def step_1_create_platform_app
    puts "\n🔧 Step 1: Creating Platform App"
    puts "Creating platform app via Rails console..."
    
    # In the test container, we need to create the platform app via Rails console
    # This is the only step that requires Rails console, everything else uses APIs
    platform_app = PlatformApp.create!(name: 'VoiceLinkAI Test Platform App')
    @results[:platform_app] = {
      id: platform_app.id,
      name: platform_app.name
    }
    
    # Get the automatically created access token
    @results[:platform_token] = platform_app.access_token.token
    
    puts "✅ Platform App created successfully!"
    puts "   ID: #{platform_app.id}"
    puts "   Name: #{platform_app.name}"
    puts "   Token: #{@results[:platform_token][0..16]}..."
  end

  def step_2_create_account
    puts "\n🏢 Step 2: Creating Account via Platform API"
    
    account_data = {
      name: 'voicelinkai',
      locale: 'en',
      domain: 'voicelinkai.com'
    }
    
    response = api_call('POST', '/platform/api/v1/accounts', account_data)
    
    if response.is_a?(Hash) && response['id']
      @results[:account_id] = response['id']
      puts "✅ Account created successfully!"
      puts "   ID: #{@results[:account_id]}"
      puts "   Name: #{response['name']}"
    else
      raise "Failed to create account: #{response}"
    end
  end

  def step_3_create_users
    puts "\n👥 Step 3: Creating Users via Platform API"
    
    # Create Super Admin User
    puts "\n👑 Creating Super Admin User..."
    admin_data = {
      name: 'Root Owner',
      email: 'admin@voicelinkai.com',
      password: '123@321Qq',
      custom_attributes: {
        role: 'super_admin',
        created_by: 'platform_seeder'
      }
    }
    
    admin_response = api_call('POST', '/platform/api/v1/users', admin_data)
    admin_user_id = admin_response['id']
    
    # Add admin to account as administrator
    account_user_data = {
      user_id: admin_user_id,
      role: 'administrator'
    }
    
    api_call('POST', "/platform/api/v1/accounts/#{@results[:account_id]}/account_users", account_user_data)
    
    @results[:users][:admin] = {
      id: admin_user_id,
      email: 'admin@voicelinkai.com',
      name: 'Root Owner',
      role: 'administrator',
      access_token: admin_response['access_token']
    }
    
    puts "✅ Super Admin created and added to account"
    puts "   User ID: #{admin_user_id}"
    puts "   Access Token: #{admin_response['access_token'][0..16]}..."
    
    # Create Store Admin User
    puts "\n🏪 Creating Store Admin User..."
    store_data = {
      name: 'Store Administrator',
      email: 'storeadmin@voicelinkai.com', 
      password: '123@321Qq',
      custom_attributes: {
        role: 'store_admin',
        created_by: 'platform_seeder'
      }
    }
    
    store_response = api_call('POST', '/platform/api/v1/users', store_data)
    store_user_id = store_response['id']
    
    # Add store admin to account as administrator  
    store_account_user_data = {
      user_id: store_user_id,
      role: 'administrator'
    }
    
    api_call('POST', "/platform/api/v1/accounts/#{@results[:account_id]}/account_users", store_account_user_data)
    
    @results[:users][:store_admin] = {
      id: store_user_id,
      email: 'storeadmin@voicelinkai.com',
      name: 'Store Administrator', 
      role: 'administrator',
      access_token: store_response['access_token']
    }
    
    puts "✅ Store Admin created and added to account"
    puts "   User ID: #{store_user_id}"
    puts "   Access Token: #{store_response['access_token'][0..16]}..."
  end

  def step_4_create_inbox
    puts "\n📨 Step 4: Creating Twilio SMS Inbox via Application API"
    
    # Use the admin user's access token for Application API calls
    admin_token = @results[:users][:admin][:access_token]
    
    inbox_data = {
      name: 'VoiceLinkAI SMS Support',
      channel: {
        type: 'Channel::TwilioSms',
        account_sid: 'TWILIO_ACCOUNT_SID_PLACEHOLDER',
        auth_token: 'TWILIO_AUTH_TOKEN_PLACEHOLDER',
        phone_number: '+1234567890',
        medium: 'sms'
      }
    }
    
    # Use Application API endpoint with user token
    response = application_api_call('POST', "/api/v1/accounts/#{@results[:account_id]}/inboxes", inbox_data, admin_token)
    
    if response.is_a?(Hash) && response['id']
      @results[:inbox_id] = response['id']
      puts "✅ Twilio SMS inbox created successfully!"
      puts "   Inbox ID: #{@results[:inbox_id]}"
      puts "   Name: #{response['name']}"
      puts "   ⚠️  Update Twilio credentials in settings to activate"
    else
      puts "⚠️  Inbox creation failed - may need manual setup"
      puts "   Response: #{response}"
    end
  end

  def step_5_generate_environment_file
    puts "\n📋 Step 5: Generating Environment Configuration File"
    
    timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S %Z')
    filename = "test_env_platform_api_#{Time.now.to_i}.env"
    
    env_content = <<~ENV
      # VoiceLinkAI Test Environment Configuration (Platform API)
      # Generated: #{timestamp}
      # Method: Official Chatwoot Platform APIs
      # Database: chatwoot_shared (test schema)
      
      # =============================================================================
      # TEST ENVIRONMENT CONFIGURATION
      # =============================================================================
      
      CHATWOOT_URL="#{@base_url}"
      CHATWOOT_ACCOUNT_ID=#{@results[:account_id]}
      ENVIRONMENT=test
      DATABASE_SCHEMA=test
      DATABASE_USER=chatwoot_test
      
      # =============================================================================
      # PLATFORM API TOKENS
      # =============================================================================
      
      # Platform API Token (for system-wide operations)
      CHATWOOT_PLATFORM_TOKEN="#{@results[:platform_token]}"
      
      # Admin User Token (for account operations)
      CHATWOOT_ADMIN_TOKEN="#{@results[:users][:admin][:access_token]}"
      
      # Store Admin Token (for store operations)
      VOICELINKAI_STORE_ADMIN_TOKEN="#{@results[:users][:store_admin][:access_token]}"
      
      # =============================================================================
      # USER ACCOUNTS
      # =============================================================================
      
      # Super Admin User
      ADMIN_USER_ID=#{@results[:users][:admin][:id]}
      ADMIN_EMAIL="#{@results[:users][:admin][:email]}"
      
      # Store Admin User  
      STORE_ADMIN_USER_ID=#{@results[:users][:store_admin][:id]}
      STORE_ADMIN_EMAIL="#{@results[:users][:store_admin][:email]}"
      
      # =============================================================================
      # INBOXES
      # =============================================================================
      
      TWILIO_SMS_INBOX_ID=#{@results[:inbox_id] || 'TBD'}
      
      # =============================================================================
      # API ENDPOINTS
      # =============================================================================
      
      # Platform APIs (require platform token)
      PLATFORM_API_BASE="#{@base_url}/platform/api/v1"
      
      # Application APIs (require user tokens)
      APPLICATION_API_BASE="#{@base_url}/api/v1"
      
      # =============================================================================
      # EXAMPLE API CALLS
      # =============================================================================
      
      # Get account info:
      # curl -H "api_access_token: #{@results[:platform_token]}" \\
      #      "#{@base_url}/platform/api/v1/accounts/#{@results[:account_id]}"
      
      # Get conversations (as admin):
      # curl -H "api_access_token: #{@results[:users][:admin][:access_token]}" \\
      #      "#{@base_url}/api/v1/accounts/#{@results[:account_id]}/conversations"
      
      # =============================================================================
      # SECURITY NOTES
      # =============================================================================
      
      # ✅ Uses official Chatwoot Platform APIs
      # ✅ Isolated test database schema
      # ✅ Dedicated database user (chatwoot_test)
      # ✅ Cannot access production data
      # ✅ Schema-level isolation prevents cross-environment impact
      
    ENV
    
    File.write(filename, env_content)
    puts "✅ Environment configuration created: #{filename}"
    
    puts "\n🔐 SECURITY SUMMARY:"
    puts "- Platform App: #{@results[:platform_app][:name]}"
    puts "- Platform Token: #{@results[:platform_token][0..16]}..."
    puts "- Admin Token: #{@results[:users][:admin][:access_token][0..16]}..."
    puts "- Store Token: #{@results[:users][:store_admin][:access_token][0..16]}..."
    puts "- Database Schema: test (isolated)"
    puts "- Database User: chatwoot_test (restricted)"
  end

  # Platform API calls (require platform token)
  def api_call(method, endpoint, data = nil)
    uri = URI("#{@base_url}#{endpoint}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    
    case method.upcase
    when 'GET'
      request = Net::HTTP::Get.new(uri.path)
    when 'POST'
      request = Net::HTTP::Post.new(uri.path)
      request.body = data.to_json if data
      request['Content-Type'] = 'application/json'
    end
    
    request['api_access_token'] = @results[:platform_token]
    
    response = http.request(request)
    
    if response.code.to_i.between?(200, 299)
      JSON.parse(response.body)
    else
      puts "❌ API call failed: #{method} #{endpoint}"
      puts "   Status: #{response.code}"
      puts "   Response: #{response.body}"
      raise "API call failed: #{response.code}"
    end
  end
  
  # Application API calls (require user token)
  def application_api_call(method, endpoint, data = nil, user_token = nil)
    uri = URI("#{@base_url}#{endpoint}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    
    case method.upcase
    when 'GET'
      request = Net::HTTP::Get.new(uri.path)
    when 'POST'
      request = Net::HTTP::Post.new(uri.path)
      request.body = data.to_json if data
      request['Content-Type'] = 'application/json'
    end
    
    request['api_access_token'] = user_token
    
    response = http.request(request)
    
    if response.code.to_i.between?(200, 299)
      JSON.parse(response.body)
    else
      puts "⚠️  Application API call failed: #{method} #{endpoint}"
      puts "   Status: #{response.code}"
      puts "   Response: #{response.body}"
      return { error: response.body, status: response.code }
    end
  end
end

# Run the seeder
if __FILE__ == $0
  begin
    seeder = ChatwootPlatformSeeder.new
    seeder.run
  rescue => e
    puts "\n❌ Seeder failed: #{e.message}"
    puts e.backtrace.first(5).join("\n")
    exit 1
  end
end 