#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

class VoiceLinkAIDeploymentSeeder
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
    puts "🚀 VoiceLinkAI Deployment Seeder - Complete Solution"
    puts "=" * 70
    puts "Target URL: #{@base_url}"
    puts "Timestamp: #{@results[:timestamp]}"
    puts ""

    if check_onboarding_available
      deploy_fresh_installation
    else
      setup_existing_installation
    end

    generate_environment_file
    display_final_summary
  end

  private

  def check_onboarding_available
    puts "🔍 Checking Installation Status..."
    
    response = http_get('/installation/onboarding')
    available = response.code == '200'
    
    if available
      puts "✅ Fresh installation detected - onboarding available"
    else
      puts "ℹ️  Existing installation detected - onboarding not available"
    end
    
    available
  end

  def deploy_fresh_installation
    puts "\n🆕 FRESH INSTALLATION DEPLOYMENT"
    puts "=" * 50
    
    step_1_onboard_first_user
    step_2_authenticate_super_admin
    step_3_setup_voicelinkai_complete
  end

  def step_1_onboard_first_user
    puts "\n👑 Step 1: Creating First User via Onboarding (Auto-SuperAdmin)"
    
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
    
    if response.code.start_with?('2') || response.code == '302'
      puts "✅ Onboarding completed - First user created with automatic SuperAdmin rights"
      @results[:users][:super_admin] = {
        email: 'admin@voicelinkai.com',
        name: 'Root Owner',
        role: 'SuperAdmin',
        password: '123@321Qq',
        created_via: 'onboarding'
      }
    else
      raise "Onboarding failed: #{response.code} - #{response.body}"
    end
  end

  def step_2_authenticate_super_admin
    puts "\n🔑 Step 2: Authenticating with Auto-Created SuperAdmin"
    
    auth_data = {
      email: 'admin@voicelinkai.com',
      password: '123@321Qq'
    }
    
    response = http_post('/auth/sign_in', auth_data)
    
    if response.code == '200'
      auth_result = JSON.parse(response.body)
      user_data = auth_result['data']['user']
      
      @results[:users][:super_admin][:id] = user_data['id']
      @results[:users][:super_admin][:token] = user_data['access_token']
      @results[:super_admin_token] = user_data['access_token']
      @results[:account_id] = user_data['accounts'].first['id']
      
      puts "✅ SuperAdmin authenticated successfully"
      puts "   User ID: #{user_data['id']}"
      puts "   Account ID: #{@results[:account_id]}"
      puts "   Token: #{@results[:super_admin_token][0..16]}..."
    else
      raise "Authentication failed: #{response.code} - #{response.body}"
    end
  end

  def setup_existing_installation
    puts "\n🔧 EXISTING INSTALLATION SETUP"
    puts "=" * 50
    
    # Use our known working tokens from development environment
    puts "Using known working development tokens..."
    @results[:platform_token] = "ofbSQrdZJ91hv8rRVHvBpbn9"
    @results[:super_admin_token] = "EUizDB3ETeQRF3gRYQ1j4gxi"
    @results[:account_id] = 1
    @results[:users][:super_admin] = {
      id: 1,
      email: 'admin@voicelinkai.com',
      name: 'Root Owner',
      role: 'SuperAdmin',
      token: "EUizDB3ETeQRF3gRYQ1j4gxi",
      created_via: 'existing'
    }
    
    puts "✅ Using existing SuperAdmin configuration"
    puts "   Account ID: #{@results[:account_id]}"
    puts "   Token: #{@results[:super_admin_token][0..16]}..."
    
    step_3_setup_voicelinkai_complete
  end

  def step_3_setup_voicelinkai_complete
    puts "\n🏗️  Step 3: Complete VoiceLinkAI Setup"
    
    create_platform_token
    create_store_admin_user
    create_twilio_inbox
  end

  def create_platform_token
    puts "\n🔧 Creating Platform Token..."
    
    if @results[:platform_token]
      puts "✅ Platform token already available: #{@results[:platform_token][0..16]}..."
      return
    end
    
    platform_data = {
      platform_app: {
        name: 'VoiceLinkAI Platform App'
      }
    }
    
    response = http_post('/super_admin/platform_apps', platform_data, @results[:super_admin_token])
    
    if response.code == '200' || response.code == '201'
      platform_result = JSON.parse(response.body)
      @results[:platform_token] = platform_result['access_token']
      puts "✅ Platform token created: #{@results[:platform_token][0..16]}..."
    else
      puts "⚠️  Platform token creation failed - continuing with SuperAdmin token"
    end
  end

  def create_store_admin_user
    puts "\n🏪 Creating Store Admin User..."
    
    user_data = {
      name: 'Store Administrator',
      email: 'storeadmin@voicelinkai.com',
      password: '123@321Qq',
      role: 'administrator'
    }
    
    response = http_post("/api/v1/accounts/#{@results[:account_id]}/agents", user_data, @results[:super_admin_token])
    
    if response.code == '200' || response.code == '201'
      user_result = JSON.parse(response.body)
      
      @results[:users][:store_admin] = {
        id: user_result['id'],
        email: 'storeadmin@voicelinkai.com',
        name: 'Store Administrator',
        role: 'administrator',
        password: '123@321Qq'
      }
      
      puts "✅ Store Admin created: ID #{user_result['id']}"
    else
      puts "⚠️  Store Admin creation failed (might already exist): #{response.code}"
    end
  end

  def create_twilio_inbox
    puts "\n📞 Creating Twilio Inbox..."
    
    twilio_data = {
      name: 'VoiceLinkAI SMS Support',
      channel: {
        type: 'Channel::TwilioSms',
        phone_number: '+1234567890',
        account_sid: 'TWILIO_ACCOUNT_SID_PLACEHOLDER',
        auth_token: 'TWILIO_AUTH_TOKEN_PLACEHOLDER'
      }
    }
    
    response = http_post("/api/v1/accounts/#{@results[:account_id]}/inboxes", twilio_data, @results[:super_admin_token])
    
    if response.code == '200' || response.code == '201'
      inbox_result = JSON.parse(response.body)
      @results[:inbox_id] = inbox_result['id']
      puts "✅ Twilio inbox created: ID #{@results[:inbox_id]}"
    else
      puts "⚠️  Twilio inbox creation failed (update credentials manually)"
    end
  end

  def generate_environment_file
    puts "\n📋 Generating Environment Configuration..."
    
    timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S %Z')
    
    env_content = <<~ENV
      # VoiceLinkAI Deployment Configuration
      # Generated: #{timestamp}
      # Method: #{@results[:users][:super_admin][:created_via] == 'onboarding' ? 'Official Chatwoot Onboarding' : 'Existing Installation'}
      
      # =============================================================================
      # CHATWOOT CONFIGURATION
      # =============================================================================
      
      CHATWOOT_URL="#{@base_url}"
      CHATWOOT_ACCOUNT_ID=#{@results[:account_id]}
      
      # =============================================================================
      # AUTHENTICATION TOKENS
      # =============================================================================
      
      # Primary SuperAdmin Token (use for all operations)
      CHATWOOT_ADMIN_TOKEN="#{@results[:super_admin_token]}"
      CHATWOOT_ADMIN_USER_ID=#{@results[:users][:super_admin][:id]}
      
      # Platform Token (for user/account management)
      CHATWOOT_PLATFORM_TOKEN="#{@results[:platform_token] || 'TBD'}"
      
      # =============================================================================
      # VOICELINKAI USERS
      # =============================================================================
      
      # Root Owner (SuperAdmin)
      VOICELINKAI_SUPER_ADMIN_EMAIL="admin@voicelinkai.com"
      VOICELINKAI_SUPER_ADMIN_PASSWORD="123@321Qq"
      VOICELINKAI_SUPER_ADMIN_USER_ID=#{@results[:users][:super_admin][:id]}
      
      # Store Administrator
      VOICELINKAI_STORE_ADMIN_EMAIL="storeadmin@voicelinkai.com"
      VOICELINKAI_STORE_ADMIN_PASSWORD="123@321Qq"
      VOICELINKAI_STORE_ADMIN_USER_ID=#{@results[:users][:store_admin]&.[](:id) || 'TBD'}
      
      # =============================================================================
      # TWILIO CONFIGURATION (Update with real values)
      # =============================================================================
      
      TWILIO_INBOX_ID=#{@results[:inbox_id] || 'TBD'}
      TWILIO_ACCOUNT_SID="your_actual_twilio_account_sid"
      TWILIO_AUTH_TOKEN="your_actual_twilio_auth_token"
      TWILIO_PHONE_NUMBER="+1234567890"
      
      # =============================================================================
      # ACCESS INFORMATION
      # =============================================================================
      
      # Login URLs
      LOGIN_URL_SUPERADMIN="#{@base_url}/super_admin/sign_in"
      LOGIN_URL_DASHBOARD="#{@base_url}/app/login"
      
      # API Test Command:
      # curl -H "api_access_token: ${CHATWOOT_ADMIN_TOKEN}" #{@base_url}/api/v1/profile
      
      # =============================================================================
      # DEPLOYMENT METADATA
      # =============================================================================
      
      DEPLOYMENT_METHOD="#{@results[:users][:super_admin][:created_via] == 'onboarding' ? 'official_onboarding' : 'existing_setup'}"
      DEPLOYMENT_TIMESTAMP="#{timestamp}"
      FIRST_USER_AUTO_SUPERADMIN=#{@results[:users][:super_admin][:created_via] == 'onboarding' ? 'true' : 'false'}
    ENV
    
    filename = "voicelinkai_final_deployment_#{Time.now.to_i}.env"
    File.write(filename, env_content)
    puts "✅ Environment file created: #{filename}"
  end

  def display_final_summary
    puts "\n🎉 VoiceLinkAI Deployment Complete!"
    puts "=" * 70
    
    puts "📊 Summary:"
    puts "   Method: #{@results[:users][:super_admin][:created_via] == 'onboarding' ? 'Fresh onboarding' : 'Existing installation'}"
    puts "   Account ID: #{@results[:account_id]}"
    puts "   SuperAdmin Token: #{@results[:super_admin_token][0..16]}..."
    puts "   Platform Token: #{@results[:platform_token] ? @results[:platform_token][0..16] + '...' : 'Not created'}"
    
    puts "\n👥 Users:"
    puts "   ✅ Root Owner: admin@voicelinkai.com (SuperAdmin)"
    puts "   #{@results[:users][:store_admin] ? '✅' : '⚠️ '} Store Admin: storeadmin@voicelinkai.com"
    
    puts "\n📞 Inbox: #{@results[:inbox_id] ? "✅ Twilio SMS (ID: #{@results[:inbox_id]})" : '⚠️  Not created'}"
    
    puts "\n🔗 Access:"
    puts "   SuperAdmin Panel: #{@base_url}/super_admin/sign_in"
    puts "   Dashboard: #{@base_url}/app/login"
    puts "   Credentials: admin@voicelinkai.com / 123@321Qq"
    
    puts "\n💡 Key Discovery:"
    puts "   🎯 First user created via Chatwoot onboarding automatically gets SuperAdmin rights!"
    puts "   🎯 This eliminates need for complex database manipulation in fresh deployments"
    puts "   🎯 Use official onboarding API for new installations, tokens for existing ones"
  end

  # HTTP Helper Methods
  def http_get(path, token = nil)
    uri = URI("#{@base_url}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.read_timeout = 30
    
    request = Net::HTTP::Get.new(uri)
    request['Content-Type'] = 'application/json'
    request['User-Agent'] = 'VoiceLinkAI-Seeder'
    request['api_access_token'] = token if token
    
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
  puts "🚀 Starting VoiceLinkAI Final Deployment Seeder..."
  
  begin
    custom_url = ARGV[0]
    options = {}
    options[:base_url] = custom_url if custom_url
    
    seeder = VoiceLinkAIDeploymentSeeder.new(options)
    seeder.perform
    
    puts "\n✅ Deployment completed successfully!"
    puts "Check the generated .env file for complete configuration details."
    
  rescue StandardError => e
    puts "\n❌ Deployment failed: #{e.message}"
    puts "   Backtrace: #{e.backtrace.first if e.backtrace}"
    exit 1
  end
end 