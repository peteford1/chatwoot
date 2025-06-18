#!/usr/bin/env ruby

# VoiceLinkAI Rails-Integrated Deployment Seeder Script
# Created: #{Time.current}
# Purpose: Sets up complete account structure using Rails models and API calls
# Usage: bundle exec rails runner scripts/deployment_seeder_rails.rb [base_url]

require 'net/http'
require 'json'
require 'uri'
require 'openssl'

class VoiceLinkAIRailsSeeder
  attr_reader :base_url, :platform_token, :super_admin_token, :account_id, :results

  def initialize(base_url = nil)
    @base_url = base_url || ENV['FRONTEND_URL'] || 'http://localhost:3000'
    @results = {
      platform_token: nil,
      super_admin_token: nil,
      account_id: nil,
      users: {},
      inbox_id: nil,
      errors: []
    }
    
    puts "🚀 VoiceLinkAI Rails Deployment Seeder"
    puts "🌐 Target URL: #{@base_url}"
    puts "📅 Started: #{Time.current}"
    puts "=" * 60
  end

  def seed!
    begin
      step_1_create_platform_app
      step_2_create_account  
      step_3_create_super_admin
      step_4_create_store_admin
      step_5_create_twilio_inbox
      step_6_generate_environment_file
      
      print_success_summary
    rescue => e
      print_error_summary(e)
      raise e
    end
  end

  private

  def step_1_create_platform_app
    puts "\n🔧 Step 1: Creating Platform App"
    
    # Create platform app using Rails model
    platform_app = PlatformApp.find_or_create_by(name: 'VoiceLinkAI Platform App') do |app|
      app.name = 'VoiceLinkAI Platform App'
    end
    
    @platform_token = platform_app.access_token.token
    @results[:platform_token] = @platform_token
    
    puts "✅ Platform app created: #{platform_app.name}"
    puts "🔑 Platform token: #{@platform_token[0..16]}..."
  end

  def step_2_create_account
    puts "\n🏢 Step 2: Creating VoiceLinkAI Account"
    
    account_data = {
      name: 'voicelinkai',
      description: 'VoiceLinkAI Account',
      locale: 'en'
    }
    
    response = api_call('POST', '/platform/api/v1/accounts', account_data, @platform_token)
    @account_id = response['id']
    @results[:account_id] = @account_id
    
    puts "✅ Account created via Platform API: ID #{@account_id}"
  end

  def step_3_create_super_admin
    puts "\n👑 Step 3: Creating Super Admin (Root User)"
    
    # Create user via Platform API
    user_data = {
      name: 'Root Owner',
      email: 'admin@voicelinkai.com',
      password: '123@321Qq',
      custom_attributes: {
        role: 'super_admin',
        created_by: 'deployment_seeder'
      }
    }
    
    user_response = api_call('POST', '/platform/api/v1/users', user_data, @platform_token)
    super_admin_user_id = user_response['id']
    
    # Add user to account as administrator
    account_user_data = {
      user_id: super_admin_user_id,
      role: 'administrator'
    }
    
    api_call('POST', "/platform/api/v1/accounts/#{@account_id}/account_users", account_user_data, @platform_token)
    
    # Create SuperAdmin record using Rails model
    user = User.find(super_admin_user_id)
    super_admin = SuperAdmin.find_or_create_by(email: 'admin@voicelinkai.com') do |sa|
      sa.name = 'Root Owner'
      sa.email = 'admin@voicelinkai.com'
      sa.password = '123@321Qq'
      sa.confirmed_at = Time.current
    end
    
    # Create access token for the super admin user (not SuperAdmin model)
    access_token = AccessToken.create!(
      owner: user,
      token: SecureRandom.hex(32)
    )
    
    @super_admin_token = access_token.token
    @results[:super_admin_token] = @super_admin_token
    @results[:users][:super_admin] = {
      id: super_admin_user_id,
      email: 'admin@voicelinkai.com',
      role: 'super_admin',
      token: @super_admin_token,
      super_admin_id: super_admin.id
    }
    
    puts "✅ Super Admin User created: ID #{super_admin_user_id}"
    puts "✅ SuperAdmin record created: ID #{super_admin.id}"
    puts "🔑 Super Admin token: #{@super_admin_token[0..16]}..."
  end

  def step_4_create_store_admin
    puts "\n🏪 Step 4: Creating Store Admin User"
    
    user_data = {
      name: 'Store Administrator',
      email: 'storeadmin@voicelinkai.com',
      password: '123@321Qq',
      custom_attributes: {
        role: 'store_admin',
        created_by: 'deployment_seeder'
      }
    }
    
    user_response = api_call('POST', '/platform/api/v1/users', user_data, @platform_token)
    store_admin_user_id = user_response['id']
    
    # Add user to account as administrator
    account_user_data = {
      user_id: store_admin_user_id,
      role: 'administrator'
    }
    
    api_call('POST', "/platform/api/v1/accounts/#{@account_id}/account_users", account_user_data, @platform_token)
    
    # Create access token for store admin
    store_admin_user = User.find(store_admin_user_id)
    store_admin_access_token = AccessToken.create!(
      owner: store_admin_user,
      token: SecureRandom.hex(32)
    )
    
    @results[:users][:store_admin] = {
      id: store_admin_user_id,
      email: 'storeadmin@voicelinkai.com',
      role: 'administrator',
      token: store_admin_access_token.token
    }
    
    puts "✅ Store Admin created: ID #{store_admin_user_id}"
    puts "🔑 Store Admin token: #{store_admin_access_token.token[0..16]}..."
  end

  def step_5_create_twilio_inbox
    puts "\n📱 Step 5: Creating Twilio Inbox"
    
    # Check if Twilio credentials are available
    twilio_account_sid = ENV['TWILIO_ACCOUNT_SID']
    twilio_auth_token = ENV['TWILIO_AUTH_TOKEN']
    twilio_phone_number = ENV['TWILIO_PHONE_NUMBER']
    
    if twilio_account_sid.present? && twilio_auth_token.present? && twilio_phone_number.present?
      twilio_data = {
        twilio_channel: {
          account_sid: twilio_account_sid,
          auth_token: twilio_auth_token,
          phone_number: twilio_phone_number,
          name: 'VoiceLinkAI Twilio SMS',
          medium: 'sms'
        }
      }
      
      begin
        response = api_call('POST', "/api/v1/accounts/#{@account_id}/channels/twilio_channel", twilio_data, @super_admin_token)
        @results[:inbox_id] = response['id']
        puts "✅ Twilio inbox created: ID #{response['id']}"
      rescue => e
        puts "❌ Twilio inbox creation failed: #{e.message}"
        @results[:errors] << "Twilio inbox: #{e.message}"
      end
    else
      puts "⚠️  Twilio inbox creation skipped - credentials not configured"
      puts "   Set TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER to enable"
      @results[:errors] << "Twilio inbox: Missing credentials (TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER)"
    end
  end

  def step_6_generate_environment_file
    puts "\n📝 Step 6: Generating Environment Variables"
    
    env_content = generate_env_content
    filename = "voicelinkai_deployment_tokens_#{Time.current.to_i}.env"
    File.write(filename, env_content)
    
    puts "✅ Environment file created: #{filename}"
  end

  # API Helper Methods
  def api_call(method, path, data = nil, token = nil)
    uri = URI("#{@base_url}#{path}")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE if uri.scheme == 'https'
    http.read_timeout = 30
    http.open_timeout = 10
    
    request = case method.upcase
    when 'POST'
      Net::HTTP::Post.new(uri)
    when 'GET'
      Net::HTTP::Get.new(uri)
    when 'PUT'
      Net::HTTP::Put.new(uri)
    end
    
    request['Content-Type'] = 'application/json'
    request['api_access_token'] = token if token
    request.body = data.to_json if data
    
    response = http.request(request)
    
    if response.code.to_i >= 400
      raise "API Error #{response.code}: #{response.body}"
    end
    
    JSON.parse(response.body)
  rescue JSON::ParserError => e
    puts "JSON Parse Error: #{e.message}"
    puts "Response body: #{response.body}"
    raise e
  end

  def generate_env_content
    timestamp = Time.current.strftime('%Y-%m-%d %H:%M:%S %Z')
    
    <<~ENV
      # VoiceLinkAI Deployment Environment Variables
      # Generated: #{timestamp}
      # Generated by: Rails Deployment Seeder
      # 
      # CRITICAL: Store these securely and update your deployment configuration

      # ======================
      # AUTHENTICATION TOKENS
      # ======================

      # Platform API Token (for account/user management via Platform API)
      VOICELINKAI_PLATFORM_TOKEN="#{@results[:platform_token]}"

      # Super Admin (Root Owner) Credentials - USE THIS AS PRIMARY ADMIN TOKEN
      VOICELINKAI_SUPER_ADMIN_TOKEN="#{@results[:super_admin_token]}"
      VOICELINKAI_SUPER_ADMIN_EMAIL="admin@voicelinkai.com"
      VOICELINKAI_SUPER_ADMIN_USER_ID=#{@results[:users][:super_admin][:id]}

      # Store Admin Credentials  
      VOICELINKAI_STORE_ADMIN_TOKEN="#{@results[:users][:store_admin][:token]}"
      VOICELINKAI_STORE_ADMIN_EMAIL="storeadmin@voicelinkai.com"
      VOICELINKAI_STORE_ADMIN_USER_ID=#{@results[:users][:store_admin][:id]}

      # Account Information
      VOICELINKAI_ACCOUNT_ID=#{@results[:account_id]}
      VOICELINKAI_ACCOUNT_NAME="voicelinkai"

      # ======================
      # FOR CHATWOOT ENVIRONMENT CONFIGS
      # ======================

      # Use the Super Admin token as the primary admin token in environment variables
      CHATWOOT_ADMIN_TOKEN="#{@results[:super_admin_token]}"
      CHATWOOT_ADMIN_USER_ID=#{@results[:users][:super_admin][:id]}
      CHATWOOT_PLATFORM_TOKEN="#{@results[:platform_token]}"
      CHATWOOT_ACCOUNT_ID=#{@results[:account_id]}

      # ======================
      # TWILIO CONFIGURATION
      # ======================

      # Set these in your deployment environment before running the seeder
      # TWILIO_ACCOUNT_SID=your_twilio_account_sid
      # TWILIO_AUTH_TOKEN=your_twilio_auth_token  
      # TWILIO_PHONE_NUMBER=your_twilio_phone_number

      # Inbox ID (if created successfully)
      #{@results[:inbox_id] ? "VOICELINKAI_INBOX_ID=#{@results[:inbox_id]}" : "# VOICELINKAI_INBOX_ID=configure_after_twilio_setup"}

      # ======================
      # DEPLOYMENT NOTES
      # ======================

      # Email Accounts Created:
      # - admin@voicelinkai.com (Super Admin + Account Administrator)
      # - storeadmin@voicelinkai.com (Account Administrator)
      #
      # Account: voicelinkai (ID: #{@results[:account_id]})
      # 
      # Both users have 'administrator' role on the account and can:
      # - Manage all conversations and contacts
      # - Configure inboxes and integrations  
      # - Manage other agents
      # - Access all account settings
      #
      # The Super Admin also has system-wide privileges via the SuperAdmin model
    ENV
  end

  def print_success_summary
    puts "\n" + "=" * 70
    puts "🎉 VoiceLinkAI Deployment Seeding COMPLETED!"
    puts "=" * 70
    
    puts "\n📋 SUMMARY:"
    puts "✅ Platform Token: #{@results[:platform_token][0..20]}..."
    puts "✅ Account: voicelinkai (ID: #{@results[:account_id]})"
    puts "✅ Super Admin: admin@voicelinkai.com (User ID: #{@results[:users][:super_admin][:id]})"
    puts "✅ Store Admin: storeadmin@voicelinkai.com (User ID: #{@results[:users][:store_admin][:id]})"
    
    if @results[:inbox_id]
      puts "✅ Twilio Inbox: ID #{@results[:inbox_id]}"
    else
      puts "⚠️  Twilio Inbox: Not created (configure credentials)"
    end
    
    puts "\n🔑 PRIMARY ADMIN TOKEN (use in environment):"
    puts "#{@results[:super_admin_token]}"
    
          puts "\n🔐 LOGIN CREDENTIALS:"
      puts "Super Admin: admin@voicelinkai.com / 123@321Qq"
      puts "Store Admin: storeadmin@voicelinkai.com / 123@321Qq"
    
    if @results[:errors].any?
      puts "\n⚠️  WARNINGS:"
      @results[:errors].each { |error| puts "   - #{error}" }
    end
    
    puts "\n📝 NEXT STEPS:"
    puts "1. 🔒 Store the generated environment file securely"
    puts "2. 🔧 Update your deployment configuration with CHATWOOT_ADMIN_TOKEN"
    puts "3. 📱 Configure Twilio credentials if needed (TWILIO_ACCOUNT_SID, etc.)"
    puts "4. 🧪 Test authentication with the generated tokens"
    puts "5. 🌐 Update WebSocket tests with new tokens"
    
    puts "\n💡 The Super Admin token is now your primary admin token for environment variables!"
  end

  def print_error_summary(error)
    puts "\n" + "=" * 70
    puts "❌ VoiceLinkAI Deployment Seeding FAILED!"
    puts "=" * 70
    puts "💥 Error: #{error.message}"
    puts "📍 Backtrace:"
    error.backtrace.first(5).each { |line| puts "   #{line}" }
    
    puts "\n🔄 Partial Results:"
    if @results[:platform_token]
      puts "✅ Platform token was created: #{@results[:platform_token][0..16]}..."
    end
    
    if @results[:account_id]
      puts "✅ Account was created: ID #{@results[:account_id]}"
    end
    
    puts "\n🛠️  Check the error and run the seeder again once issues are resolved."
  end
end

# Script execution
if __FILE__ == $0
  # This section runs when called directly, not via rails runner
  puts "❌ This script must be run via 'bundle exec rails runner'"
  puts "Usage: bundle exec rails runner scripts/deployment_seeder_rails.rb [base_url]"
  exit 1
end

# Rails runner execution
base_url = ARGV[0]
seeder = VoiceLinkAIRailsSeeder.new(base_url)
seeder.seed! 