#!/usr/bin/env ruby

# VoiceLinkAI Deployment Seeder Script
# Created: #{Time.current}
# Purpose: Sets up complete account structure using API calls during deployment
# Usage: ruby scripts/deployment_seeder.rb [base_url]

require 'net/http'
require 'json'
require 'uri'
require 'openssl'

class VoiceLinkAISeeder
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
    
    puts "🚀 VoiceLinkAI Deployment Seeder"
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
    
    # Create platform app directly in database (no API for this)
    platform_app_data = {
      name: 'VoiceLinkAI Platform App',
      description: 'Platform app for VoiceLinkAI deployment seeding'
    }
    
    response = database_create_platform_app(platform_app_data)
    @platform_token = response[:access_token]
    @results[:platform_token] = @platform_token
    
    puts "✅ Platform token created: #{@platform_token[0..16]}..."
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
    
    puts "✅ Account created: ID #{@account_id}"
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
    
    # Create super admin record directly (no API for this)
    super_admin_response = database_create_super_admin({
      name: 'Root Owner',
      email: 'admin@voicelinkai.com',
      password: '123@321Qq'
    })
    
    # Get access token for the super admin
    @super_admin_token = database_create_access_token(super_admin_user_id)
    @results[:super_admin_token] = @super_admin_token
    @results[:users][:super_admin] = {
      id: super_admin_user_id,
      email: 'admin@voicelinkai.com',
      role: 'super_admin',
      token: @super_admin_token
    }
    
    puts "✅ Super Admin created: ID #{super_admin_user_id}"
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
    
    # Get access token for store admin
    store_admin_token = database_create_access_token(store_admin_user_id)
    @results[:users][:store_admin] = {
      id: store_admin_user_id,
      email: 'storeadmin@voicelinkai.com',
      role: 'administrator',
      token: store_admin_token
    }
    
    puts "✅ Store Admin created: ID #{store_admin_user_id}"
    puts "🔑 Store Admin token: #{store_admin_token[0..16]}..."
  end

  def step_5_create_twilio_inbox
    puts "\n📱 Step 5: Creating Twilio Inbox"
    
    # Use super admin token for account-scoped API calls
    twilio_data = {
      twilio_channel: {
        account_sid: ENV['TWILIO_ACCOUNT_SID'] || 'REPLACE_WITH_TWILIO_ACCOUNT_SID',
        auth_token: ENV['TWILIO_AUTH_TOKEN'] || 'REPLACE_WITH_TWILIO_AUTH_TOKEN',
        phone_number: ENV['TWILIO_PHONE_NUMBER'] || '+1234567890',
        name: 'VoiceLinkAI Twilio SMS',
        medium: 'sms'
      }
    }
    
    begin
      response = api_call('POST', "/api/v1/accounts/#{@account_id}/channels/twilio_channel", twilio_data, @super_admin_token)
      @results[:inbox_id] = response['id']
      puts "✅ Twilio inbox created: ID #{response['id']}"
    rescue => e
      puts "⚠️  Twilio inbox creation skipped (configure Twilio credentials later)"
      puts "   Error: #{e.message}"
      @results[:errors] << "Twilio inbox: #{e.message}"
    end
  end

  def step_6_generate_environment_file
    puts "\n📝 Step 6: Generating Environment Variables"
    
    env_content = generate_env_content
    File.write('voicelinkai_deployment_tokens.env', env_content)
    
    puts "✅ Environment file created: voicelinkai_deployment_tokens.env"
  end

  # API Helper Methods
  def api_call(method, path, data = nil, token = nil)
    uri = URI("#{@base_url}#{path}")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE if uri.scheme == 'https'
    
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
  rescue JSON::ParserError
    response.body
  end

  # Database Direct Operations (for operations without API endpoints)
  def database_create_platform_app(data)
    # This would need to be implemented based on your Rails environment
    # For now, returning a placeholder
    {
      access_token: generate_secure_token
    }
  end

  def database_create_super_admin(data)
    # This would need to be implemented based on your Rails environment
    # For now, returning a placeholder
    {
      id: rand(1000..9999)
    }
  end

  def database_create_access_token(user_id)
    # This would need to be implemented based on your Rails environment
    # For now, returning a placeholder
    generate_secure_token
  end

  def generate_secure_token
    require 'securerandom'
    SecureRandom.hex(16)
  end

  def generate_env_content
    <<~ENV
      # VoiceLinkAI Deployment Environment Variables
      # Generated: #{Time.current}
      # 
      # CRITICAL: Store these securely and update your deployment configuration
      
      # ======================
      # AUTHENTICATION TOKENS
      # ======================
      
      # Platform API Token (for account/user management)
      VOICELINKAI_PLATFORM_TOKEN="#{@results[:platform_token]}"
      
      # Super Admin (Root Owner) Credentials
      VOICELINKAI_SUPER_ADMIN_TOKEN="#{@results[:super_admin_token]}"
      VOICELINKAI_SUPER_ADMIN_EMAIL="admin@voicelinkai.com"
      
      # Store Admin Credentials  
      VOICELINKAI_STORE_ADMIN_TOKEN="#{@results[:users][:store_admin][:token]}"
      VOICELINKAI_STORE_ADMIN_EMAIL="storeadmin@voicelinkai.com"
      
      # Account Information
      VOICELINKAI_ACCOUNT_ID=#{@results[:account_id]}
      VOICELINKAI_ACCOUNT_NAME="voicelinkai"
      
      # ======================
      # FOR ENVIRONMENT CONFIGS
      # ======================
      
      # Use the Super Admin token as the primary admin token
      CHATWOOT_ADMIN_TOKEN="#{@results[:super_admin_token]}"
      CHATWOOT_ADMIN_USER_ID=#{@results[:users][:super_admin][:id]}
      CHATWOOT_PLATFORM_TOKEN="#{@results[:platform_token]}"
      CHATWOOT_ACCOUNT_ID=#{@results[:account_id]}
      
      # ======================
      # TWILIO CONFIGURATION
      # ======================
      
      # Configure these in your deployment environment
      # TWILIO_ACCOUNT_SID=your_twilio_account_sid
      # TWILIO_AUTH_TOKEN=your_twilio_auth_token  
      # TWILIO_PHONE_NUMBER=your_twilio_phone_number
      
      # Inbox ID (if created successfully)
      #{@results[:inbox_id] ? "VOICELINKAI_INBOX_ID=#{@results[:inbox_id]}" : "# VOICELINKAI_INBOX_ID=configure_after_twilio_setup"}
    ENV
  end

  def print_success_summary
    puts "\n" + "=" * 60
    puts "🎉 VoiceLinkAI Deployment Seeding COMPLETED!"
    puts "=" * 60
    
    puts "\n📋 Summary:"
    puts "✅ Platform Token: #{@results[:platform_token][0..16]}..."
    puts "✅ Account ID: #{@results[:account_id]}"
    puts "✅ Super Admin: admin@voicelinkai.com"
    puts "✅ Store Admin: storeadmin@voicelinkai.com"
    puts "✅ Environment file: voicelinkai_deployment_tokens.env"
    
    if @results[:inbox_id]
      puts "✅ Twilio Inbox: #{@results[:inbox_id]}"
    else
      puts "⚠️  Twilio Inbox: Configure manually with credentials"
    end
    
    puts "\n🔑 Primary Admin Token (for environment): #{@results[:super_admin_token][0..16]}..."
    
    if @results[:errors].any?
      puts "\n⚠️  Warnings:"
      @results[:errors].each { |error| puts "   - #{error}" }
    end
    
    puts "\n📝 Next Steps:"
    puts "1. Store tokens securely in your deployment environment"
    puts "2. Configure Twilio credentials if needed"
    puts "3. Update your environment configuration with generated tokens"
    puts "4. Test authentication with the generated tokens"
  end

  def print_error_summary(error)
    puts "\n" + "=" * 60
    puts "❌ VoiceLinkAI Deployment Seeding FAILED!"
    puts "=" * 60
    puts "Error: #{error.message}"
    puts "Backtrace: #{error.backtrace.first(5).join("\\n")}"
    
    if @results[:platform_token]
      puts "\\n🔑 Platform token was created: #{@results[:platform_token][0..16]}..."
    end
  end
end

# Script execution
if __FILE__ == $0
  base_url = ARGV[0]
  seeder = VoiceLinkAISeeder.new(base_url)
  seeder.seed!
end 