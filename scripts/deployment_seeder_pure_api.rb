#!/usr/bin/env ruby

# VoiceLinkAI Pure API Deployment Seeder Script
# Created: 2025-06-16
# Purpose: Sets up complete account structure using ONLY web service API calls
# Usage: ruby scripts/deployment_seeder_pure_api.rb [base_url] [existing_platform_token]

require 'net/http'
require 'json'
require 'uri'
require 'openssl'
require 'securerandom'

class VoiceLinkAIPureAPISeeder
  attr_reader :base_url, :platform_token, :super_admin_token, :account_id, :results

  def initialize(base_url = nil, platform_token = nil)
    @base_url = base_url || ENV['FRONTEND_URL'] || 'http://localhost:3000'
    @platform_token = platform_token || ENV['CHATWOOT_PLATFORM_TOKEN']
    @results = {
      platform_token: @platform_token,
      super_admin_token: nil,
      account_id: nil,
      users: {},
      inbox_id: nil,
      errors: []
    }
    
    puts "🚀 VoiceLinkAI Pure API Deployment Seeder"
    puts "🌐 Target URL: #{@base_url}"
    puts "🔑 Platform Token: #{@platform_token ? @platform_token[0..16] + '...' : 'Not provided'}"
    puts "📅 Started: #{Time.now}"
    puts "=" * 60
  end

  def seed!
    begin
      validate_prerequisites
      step_1_verify_platform_token
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

  def validate_prerequisites
    puts "\n🔍 Step 0: Validating Prerequisites"
    
    if @platform_token.nil? || @platform_token.empty?
      raise "Platform token is required. Provide via argument or CHATWOOT_PLATFORM_TOKEN env var"
    end
    
    # Test basic connectivity
    response = api_call('GET', '/')
    if response.is_a?(Hash) && response['version']
      puts "✅ Application connectivity verified (version: #{response['version']})"
    else
      puts "⚠️  Application connectivity unclear, but proceeding..."
    end
  end

  def step_1_verify_platform_token
    puts "\n🔧 Step 1: Verifying Platform Token"
    
    begin
      # Try to use platform token - if it works, we're good
      # Platform API doesn't have a simple "verify" endpoint, so we'll test it in account creation
      @results[:platform_token] = @platform_token
      puts "✅ Platform token ready for testing"
    rescue => e
      raise "Platform token verification failed: #{e.message}"
    end
  end

  def step_2_create_account
    puts "\n🏢 Step 2: Creating VoiceLinkAI Account via Platform API"
    
    account_data = {
      name: 'voicelinkai',
      locale: 'en'
    }
    
    begin
      response = api_call('POST', '/platform/api/v1/accounts', account_data, @platform_token)
      @account_id = response['id']
      @results[:account_id] = @account_id
      
      puts "✅ Account created via Platform API: ID #{@account_id}"
    rescue => e
      if e.message.include?('422')
        # Account might already exist, try to find it
        puts "⚠️  Account creation failed (might exist), attempting alternative approach..."
        puts "   Error: #{e.message}"
        @results[:errors] << "Account creation: #{e.message}"
        raise "Cannot proceed without account ID. Please provide existing account ID or check platform token permissions."
      else
        raise e
      end
    end
  end

  def step_3_create_super_admin
    puts "\n👑 Step 3: Creating Super Admin (Root User) via Platform API"
    
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
    
    begin
      user_response = api_call('POST', '/platform/api/v1/users', user_data, @platform_token)
      super_admin_user_id = user_response['id']
      
      # Add user to account as administrator
      account_user_data = {
        user_id: super_admin_user_id,
        role: 'administrator'
      }
      
      api_call('POST', "/platform/api/v1/accounts/#{@account_id}/account_users", account_user_data, @platform_token)
      
      @results[:users][:super_admin] = {
        id: super_admin_user_id,
        email: 'admin@voicelinkai.com',
        role: 'super_admin',
        token: nil # Will be obtained via authentication API
      }
      
      puts "✅ Super Admin User created via Platform API: ID #{super_admin_user_id}"
      puts "ℹ️  Note: SuperAdmin model and access tokens require system-level API access"
      
    rescue => e
      if e.message.include?('422') && e.message.include?('taken')
        puts "⚠️  User already exists, attempting to continue..."
        # Try to get user ID by attempting login or other method
        puts "   Manual verification may be required for existing user"
        @results[:errors] << "Super admin creation: User might already exist"
      else
        raise e
      end
    end
  end

  def step_4_create_store_admin
    puts "\n🏪 Step 4: Creating Store Admin User via Platform API"
    
    user_data = {
      name: 'Store Administrator',
      email: 'storeadmin@voicelinkai.com',
      password: '123@321Qq',
      custom_attributes: {
        role: 'store_admin',
        created_by: 'deployment_seeder'
      }
    }
    
    begin
      user_response = api_call('POST', '/platform/api/v1/users', user_data, @platform_token)
      store_admin_user_id = user_response['id']
      
      # Add user to account as administrator
      account_user_data = {
        user_id: store_admin_user_id,
        role: 'administrator'
      }
      
      api_call('POST', "/platform/api/v1/accounts/#{@account_id}/account_users", account_user_data, @platform_token)
      
      @results[:users][:store_admin] = {
        id: store_admin_user_id,
        email: 'storeadmin@voicelinkai.com',
        role: 'administrator',
        token: nil # Will be obtained via authentication API
      }
      
      puts "✅ Store Admin User created via Platform API: ID #{store_admin_user_id}"
      
    rescue => e
      if e.message.include?('422') && e.message.include?('taken')
        puts "⚠️  User already exists, attempting to continue..."
        @results[:errors] << "Store admin creation: User might already exist"
      else
        raise e
      end
    end
  end

  def step_5_create_twilio_inbox
    puts "\n📱 Step 5: Creating Twilio Inbox via Account API"
    
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
        # Note: This requires an admin token, which we don't have yet via pure API
        puts "⚠️  Twilio inbox creation requires admin token (not available via pure API)"
        puts "   Skipping Twilio setup - configure manually after deployment"
        @results[:errors] << "Twilio inbox: Requires admin token (create manually after deployment)"
      rescue => e
        puts "❌ Twilio inbox creation failed: #{e.message}"
        @results[:errors] << "Twilio inbox: #{e.message}"
      end
    else
      puts "⚠️  Twilio inbox creation skipped - credentials not configured"
      puts "   Set TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER to enable"
      @results[:errors] << "Twilio inbox: Missing credentials"
    end
  end

  def step_6_generate_environment_file
    puts "\n📝 Step 6: Generating Environment Variables"
    
    env_content = generate_env_content
    filename = "voicelinkai_pure_api_deployment_#{Time.now.to_i}.env"
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
    when 'PATCH'
      Net::HTTP::Patch.new(uri)
    end
    
    request['Content-Type'] = 'application/json'
    request['api_access_token'] = token if token
    request.body = data.to_json if data
    
    response = http.request(request)
    
    if response.code.to_i >= 400
      raise "API Error #{response.code}: #{response.body}"
    end
    
    if response.body.strip.empty?
      return {}
    end
    
    JSON.parse(response.body)
  rescue JSON::ParserError => e
    # Some endpoints return non-JSON responses
    if response.code.to_i < 400
      return response.body
    else
      raise e
    end
  end

  def generate_env_content
    timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S %Z')
    
    <<~ENV
      # VoiceLinkAI Pure API Deployment Environment Variables
      # Generated: #{timestamp}
      # Generated by: Pure API Deployment Seeder
      # Method: Web Service API calls only (no direct Rails/database access)
      # 
      # CRITICAL: This deployment used pure API approach

      # ======================
      # AUTHENTICATION TOKENS
      # ======================

      # Platform API Token (provided/existing)
      VOICELINKAI_PLATFORM_TOKEN="#{@results[:platform_token]}"

      # Super Admin Credentials (created via Platform API)
      # NOTE: Access tokens must be generated via authentication API or manual process
      VOICELINKAI_SUPER_ADMIN_EMAIL="admin@voicelinkai.com"
      VOICELINKAI_SUPER_ADMIN_USER_ID=#{@results[:users][:super_admin][:id] || 'TBD'}
      # VOICELINKAI_SUPER_ADMIN_TOKEN="[Generate via authentication API]"

      # Store Admin Credentials (created via Platform API)
      VOICELINKAI_STORE_ADMIN_EMAIL="storeadmin@voicelinkai.com"
      VOICELINKAI_STORE_ADMIN_USER_ID=#{@results[:users][:store_admin][:id] || 'TBD'}
      # VOICELINKAI_STORE_ADMIN_TOKEN="[Generate via authentication API]"

      # Account Information
      VOICELINKAI_ACCOUNT_ID=#{@results[:account_id]}
      VOICELINKAI_ACCOUNT_NAME="voicelinkai"

      # ======================
      # FOR CHATWOOT ENVIRONMENT CONFIGS
      # ======================

      # Primary admin token (generate after deployment)
      # CHATWOOT_ADMIN_TOKEN="[Generate via authentication API]"
      # CHATWOOT_ADMIN_USER_ID=#{@results[:users][:super_admin][:id] || 'TBD'}
      CHATWOOT_PLATFORM_TOKEN="#{@results[:platform_token]}"
      CHATWOOT_ACCOUNT_ID=#{@results[:account_id]}

      # ======================
      # DEPLOYMENT COMPLETION STEPS
      # ======================

      # STEP 1: Generate Access Tokens
      # Use one of these methods to generate access tokens:
      #
      # Method A - Via Container/Rails Console (if available):
      # user = User.find_by(email: 'admin@voicelinkai.com')
      # token = AccessToken.create!(owner: user, token: SecureRandom.hex(32))
      # puts token.token
      #
      # Method B - Via Authentication API (if available):
      # curl -X POST "#{@base_url}/api/v1/auth/login" \\
      #   -H "Content-Type: application/json" \\
      #   -d '{"email":"admin@voicelinkai.com","password":"123@321Qq"}'
      #
      # Method C - Via WebUI Login:
      # 1. Login at #{@base_url}/auth/login
      # 2. Go to Profile Settings -> Access Tokens
      # 3. Create new access token

      # STEP 2: Create SuperAdmin Record (if needed)
      # SuperAdmin privileges require system-level access:
      # SuperAdmin.find_or_create_by(email: 'admin@voicelinkai.com') do |sa|
      #   sa.name = 'Root Owner'
      #   sa.password = '123@321Qq'
      #   sa.confirmed_at = Time.current
      # end

      # STEP 3: Create Twilio Inbox (optional)
      # Once you have admin tokens:
      # curl -X POST "#{@base_url}/api/v1/accounts/#{@results[:account_id]}/channels/twilio_channel" \\
      #   -H "api_access_token: [ADMIN_TOKEN]" \\
      #   -H "Content-Type: application/json" \\
      #   -d '{"twilio_channel":{"account_sid":"[SID]","auth_token":"[TOKEN]","phone_number":"[NUMBER]","name":"VoiceLinkAI Twilio SMS","medium":"sms"}}'

      # ======================
      # LOGIN CREDENTIALS
      # ======================

      # Super Admin Login (System + Account Access)
      # Email: admin@voicelinkai.com
      # Password: 123@321Qq
      # Role: Account Administrator (SuperAdmin record requires manual creation)

      # Store Admin Login (Account Access)
      # Email: storeadmin@voicelinkai.com
      # Password: 123@321Qq
      # Role: Account Administrator

      # ======================
      # PURE API LIMITATIONS
      # ======================

      # The following operations are NOT available via public APIs:
      # 1. Access Token Creation - Requires authentication flow or direct database access
      # 2. SuperAdmin Record Creation - No public API endpoint available
      # 3. Some admin-level operations - Require existing admin tokens

      # This pure API approach creates the account structure but requires
      # post-deployment steps to complete the authentication setup.

      # ======================
      # VERIFICATION COMMANDS
      # ======================

      # Test account access (once you have admin tokens):
      # curl -X GET "#{@base_url}/api/v1/accounts/#{@results[:account_id]}" \\
      #   -H "api_access_token: [ADMIN_TOKEN]"

      # List account agents:
      # curl -X GET "#{@base_url}/api/v1/accounts/#{@results[:account_id]}/agents" \\
      #   -H "api_access_token: [ADMIN_TOKEN]"
    ENV
  end

  def print_success_summary
    puts "\n" + "=" * 70
    puts "🎉 VoiceLinkAI Pure API Deployment COMPLETED!"
    puts "=" * 70
    
    puts "\n📋 SUMMARY:"
    puts "✅ Platform Token: #{@results[:platform_token][0..20]}..." if @results[:platform_token]
    puts "✅ Account: voicelinkai (ID: #{@results[:account_id]})" if @results[:account_id]
    
    if @results[:users][:super_admin]
      puts "✅ Super Admin: admin@voicelinkai.com (User ID: #{@results[:users][:super_admin][:id]})"
    end
    
    if @results[:users][:store_admin]
      puts "✅ Store Admin: storeadmin@voicelinkai.com (User ID: #{@results[:users][:store_admin][:id]})"
    end
    
    puts "\n🔐 LOGIN CREDENTIALS:"
    puts "Super Admin: admin@voicelinkai.com / 123@321Qq"
    puts "Store Admin: storeadmin@voicelinkai.com / 123@321Qq"
    
    if @results[:errors].any?
      puts "\n⚠️  LIMITATIONS & NEXT STEPS:"
      @results[:errors].each { |error| puts "   - #{error}" }
    end
    
    puts "\n📝 CRITICAL NEXT STEPS:"
    puts "1. 🔑 Generate access tokens for both users (see environment file for methods)"
    puts "2. 🛡️  Create SuperAdmin record for system-wide privileges"
    puts "3. 📱 Configure Twilio inbox with admin tokens"
    puts "4. 🧪 Test all functionality and update environment configuration"
    
    puts "\n💡 This pure API approach creates the foundational structure."
    puts "Complete the setup using the instructions in the generated environment file!"
  end

  def print_error_summary(error)
    puts "\n" + "=" * 70
    puts "❌ VoiceLinkAI Pure API Deployment FAILED!"
    puts "=" * 70
    puts "💥 Error: #{error.message}"
    puts "📍 Backtrace:"
    error.backtrace.first(5).each { |line| puts "   #{line}" }
    
    puts "\n🔄 Partial Results:"
    if @results[:platform_token]
      puts "✅ Platform token: #{@results[:platform_token][0..16]}..."
    end
    
    if @results[:account_id]
      puts "✅ Account created: ID #{@results[:account_id]}"
    end
    
    puts "\n🛠️  Pure API limitations encountered. Consider using hybrid approach."
  end
end

# Script execution
if __FILE__ == $0
  base_url = ARGV[0]
  platform_token = ARGV[1]
  
  puts "VoiceLinkAI Pure API Deployment Seeder"
  puts "Usage: ruby #{__FILE__} [base_url] [platform_token]"
  puts "Environment variables: FRONTEND_URL, CHATWOOT_PLATFORM_TOKEN"
  puts ""
  
  seeder = VoiceLinkAIPureAPISeeder.new(base_url, platform_token)
  seeder.seed!
end 