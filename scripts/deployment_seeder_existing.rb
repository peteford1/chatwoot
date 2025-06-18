#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

class VoiceLinkAIExistingSeeder
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
    puts "🚀 VoiceLinkAI Seeder - Existing Installation Support"
    puts "=" * 70
    puts "Target URL: #{@base_url}"
    puts "Timestamp: #{@results[:timestamp]}"
    puts ""

    step_1_find_existing_super_admin
    step_2_get_account_info
    step_3_create_platform_token
    step_4_ensure_voicelinkai_users
    step_5_create_twilio_inbox
    step_6_generate_environment_file

    puts "\n🎉 VoiceLinkAI Setup Complete!"
    puts "=" * 70
    display_summary
  end

  private

  def step_1_find_existing_super_admin
    puts "🔍 Step 1: Finding Existing SuperAdmin"
    
    # Try common SuperAdmin credentials
    admin_candidates = [
      { email: 'admin@voicelinkai.com', password: '123@321Qq' },
      { email: 'admin@voicelinkai.com', password: 'SuperAdmin123!' },
      { email: 'john@acme.inc', password: 'Password1!' },  # From seeds.rb
      { email: 'admin@chatwoot.local', password: 'admin123' },
      { email: 'superadmin@chatwoot.local', password: 'password' }
    ]
    
    authenticated = false
    
    admin_candidates.each do |candidate|
      puts "   Trying: #{candidate[:email]} / #{candidate[:password]}"
      
      response = http_post('/auth/sign_in', candidate)
      
      if response.code == '200'
        auth_result = JSON.parse(response.body)
        
        if auth_result['data'] && auth_result['data']['user']
          user_data = auth_result['data']['user']
          
          # Check if user has super admin or admin privileges
          if user_data['type'] == 'SuperAdmin' || user_data['accounts']&.any?
            @results[:users][:super_admin] = {
              id: user_data['id'],
              email: candidate[:email],
              name: user_data['name'],
              role: user_data['type'] || 'admin',
              token: user_data['access_token'],
              password: candidate[:password]
            }
            @results[:super_admin_token] = user_data['access_token']
            
            puts "   ✅ Found working SuperAdmin: #{candidate[:email]}"
            puts "      User ID: #{user_data['id']}"
            puts "      Type: #{user_data['type']}"
            puts "      Token: #{@results[:super_admin_token][0..16]}..."
            
            authenticated = true
            break
          end
        end
      end
    end
    
    unless authenticated
      puts "❌ Could not find working SuperAdmin credentials"
      puts "   Please check existing users in the database or super admin panel"
      raise "No working SuperAdmin credentials found"
    end
  end

  def step_2_get_account_info
    puts "\n🏢 Step 2: Getting Account Information"
    
    # Try to get account info from the authenticated user
    response = http_get('/api/v1/profile', @results[:super_admin_token])
    
    if response.code == '200'
      profile_data = JSON.parse(response.body)
      
      if profile_data['accounts'] && profile_data['accounts'].any?
        account = profile_data['accounts'].first
        @results[:account_id] = account['id']
        
        puts "✅ Found account: #{account['name']} (ID: #{account['id']})"
      else
        puts "⚠️  No accounts found in profile, trying accounts API..."
        
        # Fallback: try accounts API
        response = http_get('/api/v1/accounts', @results[:super_admin_token])
        if response.code == '200'
          accounts_data = JSON.parse(response.body)
          if accounts_data.any?
            @results[:account_id] = accounts_data.first['id']
            puts "✅ Found account via API: #{accounts_data.first['name']} (ID: #{@results[:account_id]})"
          end
        end
      end
    else
      puts "❌ Could not get profile: #{response.code} - #{response.body}"
    end
    
    unless @results[:account_id]
      puts "❌ Could not determine account ID"
      raise "No account found for authenticated user"
    end
  end

  def step_3_create_platform_token
    puts "\n🔧 Step 3: Creating Platform Token"
    
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

  def step_4_ensure_voicelinkai_users
    puts "\n👥 Step 4: Ensuring VoiceLinkAI Users Exist"
    
    # Check if VoiceLinkAI admin already exists
    if @results[:users][:super_admin][:email] == 'admin@voicelinkai.com'
      puts "✅ VoiceLinkAI admin already exists as SuperAdmin"
    else
      puts "🔄 Creating VoiceLinkAI admin user..."
      create_voicelinkai_admin
    end
    
    # Create store admin
    puts "🏪 Creating/checking store admin user..."
    create_store_admin
  end

  def create_voicelinkai_admin
    user_data = {
      name: 'Root Owner',
      email: 'admin@voicelinkai.com',
      password: '123@321Qq',
      role: 'administrator'
    }
    
    response = http_post("/api/v1/accounts/#{@results[:account_id]}/agents", user_data, @results[:super_admin_token])
    
    if response.code == '200' || response.code == '201'
      user_result = JSON.parse(response.body)
      
      @results[:users][:voicelinkai_admin] = {
        id: user_result['id'],
        email: 'admin@voicelinkai.com',
        name: 'Root Owner',
        role: 'administrator',
        password: '123@321Qq'
      }
      
      puts "✅ VoiceLinkAI admin created: ID #{user_result['id']}"
    else
      puts "❌ VoiceLinkAI admin creation failed: #{response.code} - #{response.body}"
      puts "   This user might already exist"
    end
  end

  def create_store_admin
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
      
      puts "✅ Store admin created: ID #{user_result['id']}"
    else
      puts "❌ Store admin creation failed: #{response.code} - #{response.body}"
      puts "   This user might already exist"
    end
  end

  def step_5_create_twilio_inbox
    puts "\n📞 Step 5: Creating Twilio Inbox"
    
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
      
      puts "✅ Twilio inbox created successfully"
      puts "   Inbox ID: #{@results[:inbox_id]}"
      puts "   ⚠️  Remember to update Twilio credentials in environment"
    else
      puts "❌ Twilio inbox creation failed: #{response.code} - #{response.body}"
      puts "   Response details: #{response.body[0..200]}..."
      puts "ℹ️  You can create this manually later"
    end
  end

  def step_6_generate_environment_file
    puts "\n📋 Step 6: Generating Environment Configuration"
    
    env_content = generate_env_content
    filename = "voicelinkai_existing_#{Time.now.to_i}.env"
    
    File.write(filename, env_content)
    puts "✅ Environment file created: #{filename}"
  end

  def generate_env_content
    timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S %Z')
    
    <<~ENV
      # VoiceLinkAI Configuration - Existing Installation
      # Generated: #{timestamp}
      # Method: Using existing SuperAdmin credentials
      
      # =============================================================================
      # CHATWOOT CONFIGURATION
      # =============================================================================
      
      CHATWOOT_URL="#{@base_url}"
      CHATWOOT_ACCOUNT_ID=#{@results[:account_id] || 'TBD'}
      
      # =============================================================================
      # AUTHENTICATION TOKENS
      # =============================================================================
      
      # Primary SuperAdmin Token
      CHATWOOT_ADMIN_TOKEN="#{@results[:super_admin_token] || 'TBD'}"
      CHATWOOT_ADMIN_USER_ID=#{@results[:users][:super_admin][:id] || 'TBD'}
      
      # Platform Token (if created)
      CHATWOOT_PLATFORM_TOKEN="#{@results[:platform_token] || 'CREATE_VIA_SUPER_ADMIN_PANEL'}"
      
      # =============================================================================
      # DISCOVERED SUPERADMIN
      # =============================================================================
      
      # Found SuperAdmin User
      DISCOVERED_ADMIN_EMAIL="#{@results[:users][:super_admin][:email]}"
      DISCOVERED_ADMIN_PASSWORD="#{@results[:users][:super_admin][:password]}"
      DISCOVERED_ADMIN_USER_ID=#{@results[:users][:super_admin][:id]}
      DISCOVERED_ADMIN_TYPE="#{@results[:users][:super_admin][:role]}"
      
      # =============================================================================
      # VOICELINKAI USERS
      # =============================================================================
      
      # VoiceLinkAI Admin (might be same as discovered admin)
      VOICELINKAI_ADMIN_EMAIL="admin@voicelinkai.com"
      VOICELINKAI_ADMIN_PASSWORD="123@321Qq"
      VOICELINKAI_ADMIN_USER_ID=#{@results[:users][:voicelinkai_admin]&.[](:id) || @results[:users][:super_admin][:id]}
      
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
      # LOGIN ACCESS
      # =============================================================================
      
      # Primary Login (discovered SuperAdmin)
      LOGIN_URL_SUPERADMIN="#{@base_url}/super_admin/sign_in"
      LOGIN_URL_DASHBOARD="#{@base_url}/app/login"
      
      # Test API Access:
      # curl -H "api_access_token: ${CHATWOOT_ADMIN_TOKEN}" #{@base_url}/api/v1/profile
      
      # =============================================================================
      # DEPLOYMENT INFO
      # =============================================================================
      
      DEPLOYMENT_METHOD="existing_installation"
      DEPLOYMENT_TIMESTAMP="#{timestamp}"
      WORKING_ADMIN_FOUND="#{@results[:users][:super_admin][:email]}"
    ENV
  end

  def display_summary
    puts "📊 Setup Summary:"
    puts "   Method: Working with Existing Installation"
    puts "   Account ID: #{@results[:account_id] || 'Not found'}"
    puts "   Primary Token: #{@results[:super_admin_token] ? @results[:super_admin_token][0..16] + '...' : 'Not available'}"
    puts "   Platform Token: #{@results[:platform_token] ? @results[:platform_token][0..16] + '...' : 'Not created'}"
    
    puts "\n👤 Working SuperAdmin:"
    if @results[:users][:super_admin]
      admin = @results[:users][:super_admin]
      puts "   ✅ #{admin[:email]} (#{admin[:role]})"
      puts "   🔑 Password: #{admin[:password]}"
      puts "   🆔 User ID: #{admin[:id]}"
    end
    
    puts "\n👥 VoiceLinkAI Users:"
    puts "   #{@results[:users][:voicelinkai_admin] ? '✅' : '⚠️ '} admin@voicelinkai.com"
    puts "   #{@results[:users][:store_admin] ? '✅' : '❌'} storeadmin@voicelinkai.com"
    
    puts "\n📞 Inbox: #{@results[:inbox_id] ? "✅ Twilio SMS (ID: #{@results[:inbox_id]})" : '❌ Not created'}"
    
    puts "\n🔗 Access URLs:"
    puts "   SuperAdmin: #{@base_url}/super_admin/sign_in"
    puts "   Dashboard: #{@base_url}/app/login"
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
  puts "🚀 Starting VoiceLinkAI Setup for Existing Installation..."
  
  begin
    # Check for custom URL
    custom_url = ARGV[0]
    options = {}
    options[:base_url] = custom_url if custom_url
    
    seeder = VoiceLinkAIExistingSeeder.new(options)
    seeder.perform
    
    puts "\n✅ Setup completed successfully!"
    puts "Check the generated .env file for configuration details."
    
  rescue StandardError => e
    puts "\n❌ Setup failed: #{e.message}"
    puts "   Backtrace: #{e.backtrace.first if e.backtrace}"
    exit 1
  end
end 