#!/usr/bin/env ruby

require 'pg'
require 'securerandom'

# Database connection
conn = PG.connect(
  host: 'chatwoot-db-fresh.postgres.database.azure.com',
  port: 5432,
  dbname: 'chatwoot_production',
  user: 'chatwootuser',
  password: 'chatwoot123'
)

begin
  puts "🔍 CHECKING EXISTING PLATFORM TOKENS..."
  puts "=" * 60
  
  # Check existing platform apps and their tokens
  platform_apps_query = <<~SQL
    SELECT pa.id, pa.name, pa.created_at, at.token, at.created_at as token_created_at
    FROM platform_apps pa
    JOIN access_tokens at ON at.owner_id = pa.id AND at.owner_type = 'PlatformApp'
    ORDER BY pa.created_at DESC
  SQL
  
  result = conn.exec(platform_apps_query)
  
  if result.ntuples > 0
    puts "📋 Found #{result.ntuples} existing platform app(s):"
    result.each do |row|
      puts "   ID: #{row['id']}"
      puts "   Name: #{row['name']}"
      puts "   Token: #{row['token']}"
      puts "   Created: #{row['created_at']}"
      puts "   " + "-" * 40
    end
    
    # Test the most recent token
    latest_token = result[0]['token']
    puts "\n🧪 Testing latest token: #{latest_token}"
    
    # Test the token via API call
    require 'net/http'
    require 'json'
    require 'uri'
    
    uri = URI("https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/platform/api/v1/accounts")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri)
    request['api_access_token'] = latest_token
    
    response = http.request(request)
    
    if response.code.to_i < 400
      puts "✅ Latest token WORKS! No need to create new one."
      puts "🔑 STABLE PLATFORM TOKEN: #{latest_token}"
      puts "=" * 60
      exit 0
    else
      puts "❌ Latest token failed: #{response.code} - #{response.message}"
    end
  else
    puts "❌ No existing platform apps found"
  end
  
  puts "\n🔧 CREATING NEW STABLE PLATFORM TOKEN..."
  puts "=" * 60
  
  # Create new platform app
  platform_app_id = SecureRandom.uuid
  app_name = "Stable API Platform App - #{Time.now.strftime('%Y%m%d_%H%M%S')}"
  
  # Insert platform app
  app_result = conn.exec_params(
    "INSERT INTO platform_apps (id, name, created_at, updated_at) VALUES ($1, $2, NOW(), NOW()) RETURNING id, name",
    [platform_app_id, app_name]
  )
  
  if app_result.ntuples > 0
    app = app_result[0]
    puts "✅ Platform App created:"
    puts "   ID: #{app['id']}"
    puts "   Name: #{app['name']}"
    
    # Generate stable token (longer for stability)
    stable_token = SecureRandom.hex(16) # 32 character token
    
    # Insert access token
    token_result = conn.exec_params(
      "INSERT INTO access_tokens (owner_id, owner_type, token, created_at, updated_at) VALUES ($1, $2, $3, NOW(), NOW()) RETURNING id, token",
      [platform_app_id, 'PlatformApp', stable_token]
    )
    
    if token_result.ntuples > 0
      token = token_result[0]
      puts "✅ Access Token created:"
      puts "   Token ID: #{token['id']}"
      puts "   Token: #{token['token']}"
      
      # Add permissions for all accounts
      accounts_result = conn.exec("SELECT id, name FROM accounts")
      accounts_result.each do |account|
        conn.exec_params(
          "INSERT INTO platform_app_permissibles (platform_app_id, permissible_type, permissible_id, created_at, updated_at) VALUES ($1, $2, $3, NOW(), NOW())",
          [platform_app_id, 'Account', account['id']]
        )
        puts "✅ Added permission for Account: #{account['name']} (ID: #{account['id']})"
      end
      
      puts "\n" + "=" * 60
      puts "🎉 STABLE PLATFORM TOKEN CREATED!"
      puts "=" * 60
      puts "Token: #{stable_token}"
      puts "=" * 60
      puts "\n📝 This token:"
      puts "   • Does NOT expire"
      puts "   • Has platform-level permissions"
      puts "   • Can access all accounts"
      puts "   • Should be used for application integrations"
      puts "\n🧪 Test with:"
      puts "curl -H 'api_access_token: #{stable_token}' \\"
      puts "     'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/platform/api/v1/accounts'"
      
    else
      puts "❌ Failed to create access token"
    end
  else
    puts "❌ Failed to create platform app"
  end
  
rescue PG::Error => e
  puts "Database error: #{e.message}"
rescue => e
  puts "Error: #{e.message}"
ensure
  conn.close if conn
end 