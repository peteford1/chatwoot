#!/usr/bin/env ruby

puts "🔍 Checking Azure Production Super Admin Status..."

# Azure production database connection details
azure_config = {
  adapter: 'postgresql',
  host: 'chatwoot-db-fresh.postgres.database.azure.com',
  port: 5432,
  database: 'chatwoot_production',
  username: 'chatwoot_prod',
  password: 'chatwoot_prod',
  sslmode: 'require'
}

begin
  # Establish connection to Azure database
  puts "🔗 Connecting to Azure production database..."
  puts "   Host: #{azure_config[:host]}"
  puts "   Database: #{azure_config[:database]}"
  
  ActiveRecord::Base.establish_connection(azure_config)
  
  # Test connection
  ActiveRecord::Base.connection.execute("SELECT 1")
  puts "   ✅ Connected successfully!"
  
  # Check if any SuperAdmin users exist
  super_admins = User.where(type: 'SuperAdmin')
  
  puts "\n📊 SuperAdmin Users Found: #{super_admins.count}"
  
  if super_admins.any?
    super_admins.each do |admin|
      puts "\n👤 SuperAdmin Details:"
      puts "   ID: #{admin.id}"
      puts "   Name: #{admin.name}"
      puts "   Email: #{admin.email}"
      puts "   Type: #{admin.type}"
      puts "   Confirmed: #{admin.confirmed_at ? 'Yes' : 'No'}"
      puts "   Created: #{admin.created_at}"
      puts "   Access Token: #{admin.access_token&.token || 'None'}"
    end
    
    puts "\n🌐 Super Admin Panel URLs:"
    puts "   Gateway: https://voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io/super_admin"
    puts "   Direct: https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/super_admin"
    
  else
    puts "❌ No SuperAdmin users found in Azure production database!"
    
    # Check if there are any users at all
    total_users = User.count
    puts "   Total users in system: #{total_users}"
    
    if total_users > 0
      puts "\n🔍 Sample users:"
      User.limit(5).each do |user|
        puts "   - #{user.email} (#{user.type || 'User'})"
      end
      
      puts "\n💡 Need to create SuperAdmin user!"
      puts "   You can promote an existing user or create a new one"
    else
      puts "   No users found at all - database might be empty"
    end
  end
  
  # Check accounts
  puts "\n🏢 Accounts in system: #{Account.count}"
  if Account.any?
    Account.limit(3).each do |account|
      puts "   - #{account.name} (ID: #{account.id})"
    end
  end

rescue ActiveRecord::ConnectionNotEstablished => e
  puts "❌ Failed to connect to Azure database: #{e.message}"
  puts "   Check if database credentials are correct"
  puts "   Check if IP is whitelisted for Azure PostgreSQL"
  
rescue => e
  puts "💥 Error checking Azure SuperAdmin status: #{e.message}"
  puts "   Backtrace: #{e.backtrace.first(5).join("\n   ")}"
end

puts "\n✨ Azure SuperAdmin status check completed!" 