#!/usr/bin/env ruby

# Run this in Rails console: rails console
# Or as a script: rails runner check_database_tokens.rb

puts "🔍 CHECKING DATABASE FOR ACCESS TOKENS"
puts "=" * 50

# Test tokens we've been trying to use
TEST_TOKENS = [
  "baea8676c67aba47c08564ce",
  "SamnuRSUjB4ZpktAqhLqxjeZ", 
  "NKXxMhyS5hWqGzCJdNfqxjeZ",
  "PDcyku9tpAYnNytixsfmoCHo",
  "xMHQXEmNJYXRRUnXeb9s74Uu",
  "xyoWbZdQ7UM8Dy65WisxUEnZ",
  "341179b44e238f00c018e9b8e98fcf620a9ff567745efd8d4dd7613b9b5a33f9",
  "J8mwDmmcZbuYs6a672oT8TW6"
]

puts "\n📊 ACCESS TOKEN DATABASE ANALYSIS:"

# Check if AccessToken model exists
begin
  total_tokens = AccessToken.count
  puts "\n✅ Total access tokens in database: #{total_tokens}"
rescue => e
  puts "\n❌ Error accessing AccessToken model: #{e.message}"
  exit 1
end

# Check each test token
puts "\n🔍 CHECKING TEST TOKENS:"

TEST_TOKENS.each_with_index do |token, index|
  puts "\n#{index + 1}. Token: #{token[0..15]}..."
  
  begin
    access_token = AccessToken.find_by(token: token)
    
    if access_token
      puts "   ✅ FOUND in database"
      puts "   Owner Type: #{access_token.owner_type}"
      puts "   Owner ID: #{access_token.owner_id}"
      puts "   Created: #{access_token.created_at}"
      puts "   Updated: #{access_token.updated_at}"
      
      # Check owner details
      if access_token.owner
        owner = access_token.owner
        puts "   Owner Details:"
        
        case owner
        when User
          puts "     Type: User"
          puts "     Name: #{owner.name}"
          puts "     Email: #{owner.email}"
          puts "     Role: #{owner.role}"
          puts "     Account ID: #{owner.account_id if owner.respond_to?(:account_id)}"
          
        when PlatformApp
          puts "     Type: Platform App"
          puts "     Name: #{owner.name}"
          puts "     Created: #{owner.created_at}"
          
        when AgentBot
          puts "     Type: Agent Bot"
          puts "     Name: #{owner.name}"
          puts "     Account ID: #{owner.account_id if owner.respond_to?(:account_id)}"
          
        else
          puts "     Type: #{owner.class}"
          puts "     Details: #{owner.inspect}"
        end
      else
        puts "   ⚠️  Owner not found (orphaned token)"
      end
      
    else
      puts "   ❌ NOT FOUND in database"
    end
    
  rescue => e
    puts "   ❌ Error checking token: #{e.message}"
  end
end

# Show recent tokens
puts "\n📋 RECENT ACCESS TOKENS (last 10):"

begin
  recent_tokens = AccessToken.order(created_at: :desc).limit(10)
  
  recent_tokens.each_with_index do |token, index|
    puts "\n#{index + 1}. Token: #{token.token[0..15]}..."
    puts "   Owner: #{token.owner_type} ##{token.owner_id}"
    puts "   Created: #{token.created_at}"
    
    if token.owner
      case token.owner
      when User
        puts "   User: #{token.owner.name} (#{token.owner.email})"
      when PlatformApp
        puts "   Platform App: #{token.owner.name}"
      when AgentBot
        puts "   Agent Bot: #{token.owner.name}"
      end
    end
  end
  
rescue => e
  puts "❌ Error fetching recent tokens: #{e.message}"
end

# Check for platform apps
puts "\n🏢 PLATFORM APPS:"

begin
  platform_apps = PlatformApp.all
  
  if platform_apps.any?
    platform_apps.each_with_index do |app, index|
      puts "\n#{index + 1}. #{app.name}"
      puts "   ID: #{app.id}"
      puts "   Created: #{app.created_at}"
      
      if app.access_token
        puts "   Token: #{app.access_token.token[0..15]}..."
        puts "   Token Created: #{app.access_token.created_at}"
      else
        puts "   ❌ No access token"
      end
    end
  else
    puts "\n❌ No platform apps found"
  end
  
rescue => e
  puts "❌ Error checking platform apps: #{e.message}"
end

# Check for super admin users
puts "\n👑 SUPER ADMIN USERS:"

begin
  super_admins = User.where(type: 'SuperAdmin')
  
  if super_admins.any?
    super_admins.each_with_index do |user, index|
      puts "\n#{index + 1}. #{user.name} (#{user.email})"
      puts "   ID: #{user.id}"
      puts "   Created: #{user.created_at}"
      
      if user.access_token
        puts "   Token: #{user.access_token.token[0..15]}..."
        puts "   Token Created: #{user.access_token.created_at}"
      else
        puts "   ❌ No access token"
      end
    end
  else
    puts "\n❌ No super admin users found"
  end
  
rescue => e
  puts "❌ Error checking super admin users: #{e.message}"
end

# Check regular admin users in account 22
puts "\n👤 ADMIN USERS IN ACCOUNT 22:"

begin
  account_22 = Account.find_by(id: 22)
  
  if account_22
    puts "\nAccount 22: #{account_22.name}"
    
    admin_users = account_22.users.where(role: ['administrator', 'admin'])
    
    if admin_users.any?
      admin_users.each_with_index do |user, index|
        puts "\n#{index + 1}. #{user.name} (#{user.email})"
        puts "   ID: #{user.id}"
        puts "   Role: #{user.role}"
        puts "   Created: #{user.created_at}"
        
        if user.access_token
          puts "   Token: #{user.access_token.token[0..15]}..."
          puts "   Token Created: #{user.access_token.created_at}"
        else
          puts "   ❌ No access token"
        end
      end
    else
      puts "\n❌ No admin users found in account 22"
    end
  else
    puts "\n❌ Account 22 not found"
  end
  
rescue => e
  puts "❌ Error checking account 22 users: #{e.message}"
end

puts "\n" + "="*50
puts "Database token analysis complete."
puts "="*50 