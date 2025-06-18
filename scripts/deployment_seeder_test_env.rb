#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

class VoiceLinkAITestDeploymentSeeder
  def initialize
    @base_url = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
    @results = {
      users: {},
      account_id: nil,
      super_admin_token: nil,
      platform_token: nil,
      inbox_id: nil,
      method: 'test_environment_seeder'
    }
    
    puts "🚀 VoiceLinkAI Test Environment Deployment Seeder"
    puts "=" * 60
    puts "Target URL: #{@base_url}"
    puts "Environment: TEST (using test schema in chatwoot_shared database)"
    puts "=" * 60
  end

  def run
    puts "\n📋 STEP 1: Check Installation Status"
    if installation_completed?
      puts "✅ Installation is complete - using existing installation approach"
      handle_existing_installation
    else
      puts "🔧 Installation not complete - using onboarding approach"
      handle_fresh_installation
    end
    
    generate_environment_file
    puts "\n🎉 Test Environment Deployment Complete!"
  end

  private

  def installation_completed?
    uri = URI("#{@base_url}/installation/onboarding")
    response = make_request(uri, :get)
    
    # If it redirects (302/301), installation is complete
    response.code.to_i >= 300 && response.code.to_i < 400
  end

  def handle_fresh_installation
    puts "\n🔧 Using Fresh Installation Approach (Official Onboarding)"
    
    # Try onboarding API
    onboard_uri = URI("#{@base_url}/installation/onboarding")
    onboard_data = {
      user: {
        name: "Root Owner",
        email: "admin@voicelinkai.com",
        password: "123@321Qq",
        password_confirmation: "123@321Qq"
      },
      account_name: "voicelinkai"
    }
    
    puts "📤 Creating SuperAdmin via onboarding..."
    response = make_request(onboard_uri, :post, onboard_data.to_json, {
      'Content-Type' => 'application/json'
    })
    
    if response.code.to_i == 200
      puts "✅ Onboarding successful!"
      # Parse response and extract tokens
      data = JSON.parse(response.body)
      @results[:users][:super_admin] = {
        id: data['user']['id'],
        email: data['user']['email'],
        created_via: 'onboarding'
      }
      @results[:account_id] = data['account']['id']
      @results[:super_admin_token] = data['user']['access_token']
    else
      puts "❌ Onboarding failed: #{response.code} #{response.body}"
      puts "🔄 Falling back to existing installation approach..."
      handle_existing_installation
    end
  end

  def handle_existing_installation
    puts "\n🔧 Using Existing Installation Approach"
    
    # Try to find existing super admin user
    puts "🔍 Looking for existing SuperAdmin user..."
    
    # Check if we can find admin@voicelinkai.com
    if try_login_existing_user
      puts "✅ Found existing admin@voicelinkai.com user"
    else
      puts "❌ No existing admin@voicelinkai.com user found"
      puts "💡 You may need to create the user manually or run the Rails console approach"
      create_user_via_api
    end
  end

  def try_login_existing_user
    login_uri = URI("#{@base_url}/auth/sign_in")
    login_data = {
      email: "admin@voicelinkai.com",
      password: "123@321Qq"
    }
    
    response = make_request(login_uri, :post, login_data.to_json, {
      'Content-Type' => 'application/json'
    })
    
    if response.code.to_i == 200
      auth_token = response['access-token']
      client = response['client']
      uid = response['uid']
      
      if auth_token
        @results[:super_admin_token] = auth_token
        @results[:users][:super_admin] = {
          email: "admin@voicelinkai.com",
          token: auth_token,
          created_via: 'existing_login'
        }
        
        # Get user profile to get ID
        profile_uri = URI("#{@base_url}/api/v1/profile")
        profile_response = make_request(profile_uri, :get, nil, {
          'access-token' => auth_token,
          'client' => client,
          'uid' => uid
        })
        
        if profile_response.code.to_i == 200
          profile = JSON.parse(profile_response.body)
          @results[:users][:super_admin][:id] = profile['id']
          @results[:account_id] = profile['accounts'].first['id'] if profile['accounts']&.any?
        end
        
        return true
      end
    end
    
    false
  end

  def create_user_via_api
    puts "\n🔧 Creating user via Platform API (if available)..."
    
    # This would require an existing platform token, which we don't have
    # In this case, recommend manual creation
    puts "⚠️  Platform API creation requires existing tokens"
    puts "💡 Recommended: Create user manually via Rails console in test container"
    puts ""
    puts "Rails Console Commands:"
    puts "user = User.create!(name: 'Root Owner', email: 'admin@voicelinkai.com', password: '123@321Qq', password_confirmation: '123@321Qq', type: 'SuperAdmin', confirmed_at: Time.current)"
    puts "account = Account.create!(name: 'voicelinkai')"
    puts "AccountUser.create!(user: user, account: account, role: :administrator)"
    puts "puts \"Token: \#{user.access_token.token}\""
  end

  def make_request(uri, method, body = nil, headers = {})
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    
    case method
    when :get
      request = Net::HTTP::Get.new(uri.path)
    when :post
      request = Net::HTTP::Post.new(uri.path)
      request.body = body if body
    end
    
    headers.each { |key, value| request[key] = value }
    
    http.request(request)
  end

  def generate_environment_file
    puts "\n📋 Generating Environment Configuration..."
    
    timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S %Z')
    
    env_content = <<~ENV
      # VoiceLinkAI Test Environment Configuration
      # Generated: #{timestamp}
      # Database: chatwoot_shared (test schema)
      # User: chatwoot_test (isolated test database user)
      
      # =============================================================================
      # TEST ENVIRONMENT CONFIGURATION
      # =============================================================================
      
      CHATWOOT_URL="#{@base_url}"
      CHATWOOT_ACCOUNT_ID=#{@results[:account_id] || 'TBD'}
      ENVIRONMENT=test
      DATABASE_SCHEMA=test
      DATABASE_USER=chatwoot_test
      
      # =============================================================================
      # AUTHENTICATION TOKENS (TEST SCHEMA)
      # =============================================================================
      
      # These tokens are specific to the TEST schema and chatwoot_test database user
      CHATWOOT_ADMIN_TOKEN="#{@results[:super_admin_token] || 'TBD'}"
      CHATWOOT_ADMIN_USER_ID=#{@results[:users][:super_admin]&.[](:id) || 'TBD'}
      CHATWOOT_PLATFORM_TOKEN="#{@results[:platform_token] || 'TBD'}"
      
      # =============================================================================
      # VOICELINKAI USERS (TEST ENVIRONMENT)
      # =============================================================================
      
      # Root Owner (SuperAdmin)
      VOICELINKAI_SUPER_ADMIN_EMAIL="admin@voicelinkai.com"
      VOICELINKAI_SUPER_ADMIN_PASSWORD="123@321Qq"
      
      # =============================================================================
      # DATABASE SECURITY INFORMATION
      # =============================================================================
      
      # Test environment uses isolated database user
      TEST_DB_USER="chatwoot_test"
      TEST_DB_PASSWORD="TestSecure2025!"
      TEST_DB_CONNECTION="postgresql://chatwoot_test:TestSecure2025!@chatwoot-db-fresh.postgres.database.azure.com:5432/chatwoot_shared?options=-csearch_path%3Dtest"
      
      # =============================================================================
      # DEPLOYMENT METADATA
      # =============================================================================
      
      DEPLOYMENT_METHOD="test_environment_seeder"
      DEPLOYMENT_TIMESTAMP="#{timestamp}"
      ENVIRONMENT_ISOLATION="true"
      DEDICATED_DB_USER="chatwoot_test"
      SCHEMA_ISOLATION="test"
    ENV
    
    filename = "test_env_deployment_#{Time.now.to_i}.env"
    File.write(filename, env_content)
    puts "✅ Test environment configuration created: #{filename}"
    
    puts "\n🔐 SECURITY SUMMARY:"
    puts "- Using dedicated database user: chatwoot_test"
    puts "- Isolated schema: test"
    puts "- Cannot access other environment data"
    puts "- Tokens are specific to test schema"
  end
end

# Run the seeder
seeder = VoiceLinkAITestDeploymentSeeder.new
seeder.run 