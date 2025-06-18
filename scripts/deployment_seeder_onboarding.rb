#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

class VoiceLinkAIOnboardingSeeder
  attr_reader :base_url, :results

  def initialize(options = {})
    @base_url = options[:base_url] || ENV['CHATWOOT_URL'] || 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
    @results = {
      platform_token: nil,
      super_admin_token: nil,
      account_id: nil,
      users: {},
      inbox_id: nil,
      timestamp: Time.now.strftime('%Y-%m-%d %H:%M:%S %Z')
    }
  end

  def perform
    puts "🚀 VoiceLinkAI Deployment Seeder - Official Onboarding Approach"
    puts "=" * 70
    puts "Target URL: #{@base_url}"
    puts "Timestamp: #{@results[:timestamp]}"
    puts ""

    step_1_check_onboarding_status
    step_2_create_first_user_via_onboarding
    step_3_get_super_admin_credentials
    step_4_create_platform_token
    step_5_create_second_user
    step_6_create_twilio_inbox
    step_7_generate_environment_file

    puts "\n🎉 VoiceLinkAI Deployment Complete!"
    puts "=" * 70
    display_summary
  end

  private

  def step_1_check_onboarding_status
    puts "🔍 Step 1: Checking Onboarding Status"
    
    begin
      response = http_get('/installation/onboarding')
      
      if response.code == '200'
        puts "✅ Onboarding is available and required"
        @onboarding_available = true
      else
        puts "ℹ️  Onboarding not available (Status: #{response.code})"
        puts "   This likely means installation is already completed"
        @onboarding_available = false
      end
    rescue => e
      puts "⚠️  Could not check onboarding status: #{e.message}"
      @onboarding_available = false
    end
  end

  def step_2_create_first_user_via_onboarding
    puts "\n👑 Step 2: Creating First User (Auto-SuperAdmin)"
    
    if @onboarding_available
      onboarding_data = {
        user: {
          name: 'Root Owner',
          email: 'admin@voicelinkai.com',
          company: 'voicelinkai'
        },
        password: '123@321Qq',
        subscribe_to_updates: false
      }
      
      response = http_post('/installation/onboarding', onboarding_data)
      
      if response.code.start_with?('2') || response.code == '302' # Success or redirect
        puts "✅ Onboarding completed - First user created with SuperAdmin rights"
        @results[:users][:super_admin] = {
          email: 'admin@voicelinkai.com',
          name: 'Root Owner',
          role: 'super_admin',
          created_via: 'onboarding'
        }
      else
        puts "❌ Onboarding failed: #{response.code} - #{response.body}"
        raise "Onboarding process failed"
      end
    else
      puts "⏭️  Skipping onboarding - assuming first user already exists"
      @results[:users][:super_admin] = {
        email: 'admin@voicelinkai.com',
        name: 'Root Owner', 
        role: 'super_admin',
        created_via: 'existing'
      }
    end
  end

  def step_3_get_super_admin_credentials
    puts "\n🔑 Step 3: Getting SuperAdmin Credentials"
    
    # Try to authenticate with the super admin user
    auth_data = {
      email: 'admin@voicelinkai.com',
      password: '123@321Qq'
    }
    
    # First, try to get account info to find the account ID
    response = http_post('/auth/sign_in', auth_data)
    
    if response.code == '200'
      auth_result = JSON.parse(response.body)
      
      if auth_result['data'] && auth_result['data']['user']
        user_data = auth_result['data']['user']
        @results[:users][:super_admin][:id] = user_data['id']
        @results[:users][:super_admin][:token] = user_data['access_token']
        @results[:super_admin_token] = user_data['access_token']
        
        # Get account ID from user's accounts
        if user_data['accounts'] && user_data['accounts'].any?
          @results[:account_id] = user_data['accounts'].first['id']
          puts "✅ SuperAdmin authenticated successfully"
          puts "   User ID: #{user_data['id']}"
          puts "   Account ID: #{@results[:account_id]}"
          puts "   Token: #{@results[:super_admin_token][0..16]}..."
        else
          raise "No accounts found for SuperAdmin user"
        end
      else
        raise "Invalid authentication response format"
      end
    else
      puts "❌ Authentication failed: #{response.code} - #{response.body}"
      raise "Could not authenticate SuperAdmin user"
    end
  end

  def step_4_create_platform_token
    puts "\n🔧 Step 4: Creating Platform Token"
    
    # Use SuperAdmin token to create a platform app
    platform_data = {
      platform_app: {
        name: 'VoiceLinkAI Platform App'
      }
    }
    
    response = http_post('/super_admin/platform_apps', platform_data, @results[:super_admin_token])
    
    if response.code == '200' || response.code == '201'
      platform_result = JSON.parse(response.body)
      
      if platform_result['access_token']
        @results[:platform_token] = platform_result['access_token']
        puts "✅ Platform token created successfully"
        puts "   Token: #{@results[:platform_token][0..16]}..."
      else
        puts "⚠️  Platform app created but token not in expected format"
        puts "   Response: #{platform_result}"
      end
    else
      puts "❌ Platform app creation failed: #{response.code} - #{response.body}"
      puts "ℹ️  Continuing without platform token (will use SuperAdmin token)"
    end
  end

  def step_5_create_second_user
    puts "\n🏪 Step 5: Creating Store Admin User"
    
    user_data = {
      name: 'Store Administrator',
      email: 'storeadmin@voicelinkai.com',
      password: '123@321Qq',
      role: 'administrator'
    }
    
    # Use the regular API to create the second user
    response = http_post("/api/v1/accounts/#{@results[:account_id]}/agents", user_data, @results[:super_admin_token])
    
    if response.code == '200' || response.code == '201'
      user_result = JSON.parse(response.body)
      
      @results[:users][:store_admin] = {
        id: user_result['id'],
        email: 'storeadmin@voicelinkai.com',
        name: 'Store Administrator',
        role: 'administrator'
      }
      
      puts "✅ Store Admin created successfully"
      puts "   User ID: #{user_result['id']}"
    else
      puts "❌ Store Admin creation failed: #{response.code} - #{response.body}"
      puts "ℹ️  Continuing without second user"
    end
  end

  def step_6_create_twilio_inbox
    puts "\n📞 Step 6: Creating Twilio Inbox"
    
    twilio_data = {
      channel: {
        type: 'Channel::TwilioSms',
        phone_number: '+1234567890',
        account_sid: 'TWILIO_ACCOUNT_SID_PLACEHOLDER',
        auth_token: 'TWILIO_AUTH_TOKEN_PLACEHOLDER'
      },
      inbox: {
        name: 'VoiceLinkAI SMS Support'
      }
    }
    
    response = http_post("/api/v1/accounts/#{@results[:account_id]}/inboxes", twilio_data, @results[:super_admin_token])
    
    if response.code == '200' || response.code == '201'
      inbox_result = JSON.parse(response.body)
      @results[:inbox_id] = inbox_result['id']
      
      puts "✅ Twilio inbox created successfully"
      puts "   Inbox ID: #{@results[:inbox_id]}"
      puts "   ⚠️  Remember to update Twilio credentials in environment"
    else
      puts "❌ Twilio inbox creation failed: #{response.code} - #{response.body}"
      puts "ℹ️  You can create this manually later"
    end
  end

  def step_7_generate_environment_file
    puts "\n📋 Step 7: Generating Environment Configuration"
    
    env_content = generate_env_content
    filename = "voicelinkai_deployment_#{Time.now.to_i}.env"
    
    File.write(filename, env_content)
    puts "✅ Environment file created: #{filename}"
  end

  def generate_env_content
    timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S %Z')
    
    <<~ENV
      # VoiceLinkAI Deployment Configuration
      # Generated: #{timestamp}
      # Via: Official Chatwoot Onboarding API
      
      # =============================================================================
      # CHATWOOT CONFIGURATION
      # =============================================================================
      
      CHATWOOT_URL="#{@base_url}"
      CHATWOOT_ACCOUNT_ID=#{@results[:account_id] || 'TBD'}
      
      # =============================================================================
      # AUTHENTICATION TOKENS
      # =============================================================================
      
      # SuperAdmin Token (Primary - use for all admin operations)
      CHATWOOT_ADMIN_TOKEN="#{@results[:super_admin_token] || 'TBD'}"
      CHATWOOT_ADMIN_USER_ID=#{@results[:users][:super_admin][:id] || 'TBD'}
      
      # Platform Token (if created)
      CHATWOOT_PLATFORM_TOKEN="#{@results[:platform_token] || 'CREATE_VIA_SUPER_ADMIN_PANEL'}"
      
      # =============================================================================
      # VOICELINKAI USERS
      # =============================================================================
      
      # Root Owner (SuperAdmin)
      VOICELINKAI_SUPER_ADMIN_EMAIL="admin@voicelinkai.com"
      VOICELINKAI_SUPER_ADMIN_PASSWORD="123@321Qq"
      VOICELINKAI_SUPER_ADMIN_USER_ID=#{@results[:users][:super_admin][:id] || 'TBD'}
      
      # Store Administrator
      VOICELINKAI_STORE_ADMIN_EMAIL="storeadmin@voicelinkai.com"
      VOICELINKAI_STORE_ADMIN_PASSWORD="123@321Qq"
      VOICELINKAI_STORE_ADMIN_USER_ID=#{@results[:users][:store_admin][:id] || 'TBD'}
      
      # =============================================================================
      # TWILIO CONFIGURATION (Update with real values)
      # =============================================================================
      
      TWILIO_INBOX_ID=#{@results[:inbox_id] || 'TBD'}
      TWILIO_ACCOUNT_SID="your_actual_twilio_account_sid"
      TWILIO_AUTH_TOKEN="your_actual_twilio_auth_token"
      TWILIO_PHONE_NUMBER="+1234567890"
      
      # =============================================================================
      # USAGE INSTRUCTIONS
      # =============================================================================
      
      # 1. Update Twilio credentials above with real values
      # 2. Use CHATWOOT_ADMIN_TOKEN for all API operations
      # 3. Login URLs:
      #    - SuperAdmin Panel: #{@base_url}/super_admin/sign_in
      #    - Regular Dashboard: #{@base_url}/app/login
      # 4. API Testing:
      #    curl -H "api_access_token: ${CHATWOOT_ADMIN_TOKEN}" #{@base_url}/api/v1/profile
      
      # =============================================================================
      # DEPLOYMENT INFO
      # =============================================================================
      
      DEPLOYMENT_METHOD="onboarding_api"
      DEPLOYMENT_TIMESTAMP="#{timestamp}"
      FIRST_USER_CREATED_VIA="#{@results[:users][:super_admin][:created_via] || 'unknown'}"
    ENV
  end

  def display_summary
    puts "📊 Deployment Summary:"
    puts "   Method: Official Chatwoot Onboarding API"
    puts "   Account ID: #{@results[:account_id] || 'Not created'}"
    puts "   SuperAdmin Token: #{@results[:super_admin_token] ? @results[:super_admin_token][0..16] + '...' : 'Not available'}"
    puts "   Platform Token: #{@results[:platform_token] ? @results[:platform_token][0..16] + '...' : 'Not created'}"
    
    if @results[:users][:super_admin]
      puts "\n👥 Users Created:"
      puts "   ✅ Root Owner: admin@voicelinkai.com (SuperAdmin)"
      puts "   #{@results[:users][:store_admin] ? '✅' : '❌'} Store Admin: storeadmin@voicelinkai.com"
    end
    
    puts "\n📞 Inbox: #{@results[:inbox_id] ? "✅ Twilio SMS (ID: #{@results[:inbox_id]})" : '❌ Not created'}"
    
    puts "\n🔗 Access URLs:"
    puts "   SuperAdmin: #{@base_url}/super_admin/sign_in"
    puts "   Dashboard: #{@base_url}/app/login"
  end

  # HTTP Helper Methods
  def http_get(path)
    uri = URI("#{@base_url}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.read_timeout = 30
    
    request = Net::HTTP::Get.new(uri)
    request['Content-Type'] = 'application/json'
    request['User-Agent'] = 'VoiceLinkAI-Seeder'
    
    http.request(request)
  end

  def http_post(path, data, token = nil)
    uri = URI("#{@base_url}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.read_timeout = 30
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['User-Agent'] = 'VoiceLinkAI-Seeder'
    request['api_access_token'] = token if token
    request.body = data.to_json
    
    http.request(request)
  end
end

# Script execution
if __FILE__ == $0
  puts "🚀 Starting VoiceLinkAI Deployment via Official Onboarding..."
  
  begin
    # Check for custom URL
    custom_url = ARGV[0]
    options = {}
    options[:base_url] = custom_url if custom_url
    
    seeder = VoiceLinkAIOnboardingSeeder.new(options)
    seeder.perform
    
    puts "\n✅ Deployment completed successfully!"
    puts "Check the generated .env file for configuration details."
    
  rescue StandardError => e
    puts "\n❌ Deployment failed: #{e.message}"
    puts "   Backtrace: #{e.backtrace.first if e.backtrace}"
    exit 1
  end
end 