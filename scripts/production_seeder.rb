#!/usr/bin/env ruby
# Production Seeder for Chatwoot
# Creates initial account and admin user for production deployments

require_relative '../config/environment'

class ProductionSeeder
  def self.seed!
    new.seed!
  end

  def initialize
    @account_name = ENV['SEED_ACCOUNT_NAME'] || 'VoiceLink AI'
    @user_email = ENV['SEED_USER_EMAIL'] || 'admin@voicelinkai.com'
    @user_password = ENV['SEED_USER_PASSWORD'] || 'Password1!'
    @user_name = ENV['SEED_USER_NAME'] || 'Admin User'
    
    # Store admin user details
    @store_admin_email = ENV['SEED_STORE_ADMIN_EMAIL'] || 'storeadmin@voicelinkai.com'
    @store_admin_password = ENV['SEED_STORE_ADMIN_PASSWORD'] || 'Password1!'
    @store_admin_name = ENV['SEED_STORE_ADMIN_NAME'] || 'Store Admin'
  end

  def seed!
    puts "🌱 Starting production seeding..."
    
    # Load installation configs first
    puts "📋 Loading installation configs..."
    GlobalConfig.clear_cache
    ConfigLoader.new.process

    # Create account if it doesn't exist
    account = find_or_create_account
    
    # Create admin user if it doesn't exist
    user = find_or_create_user
    
    # Create store admin user if it doesn't exist
    store_admin = find_or_create_store_admin
    
    # Create account-user relationships
    create_account_user_relationship(account, user)
    create_account_user_relationship(account, store_admin)
    
    puts "✅ Production seeding completed successfully!"
    puts "📊 Summary:"
    puts "   - Account: #{account.name} (ID: #{account.id})"
    puts "   - Super Admin: #{user.name} <#{user.email}> (ID: #{user.id})"
    puts "   - Store Admin: #{store_admin.name} <#{store_admin.email}> (ID: #{store_admin.id})"
    puts "   - Login URL: #{ENV['FRONTEND_URL'] || 'https://your-chatwoot-domain.com'}"
    puts ""
    puts "🔐 Login Credentials:"
    puts "   Super Admin - Email: #{user.email}, Password: #{@user_password}"
    puts "   Store Admin - Email: #{store_admin.email}, Password: #{@store_admin_password}"
  end

  private

  def find_or_create_account
    account = Account.find_by(name: @account_name)
    
    if account
      puts "📁 Found existing account: #{account.name}"
    else
      puts "🏢 Creating account: #{@account_name}"
      account = Account.create!(name: @account_name)
      puts "✅ Account created: #{account.name} (ID: #{account.id})"
    end
    
    account
  end

  def find_or_create_user
    user = User.find_by(email: @user_email)
    
    if user
      puts "👤 Found existing super admin user: #{user.email}"
    else
      puts "👤 Creating super admin user: #{@user_email}"
      user = User.new(
        name: @user_name,
        email: @user_email,
        password: @user_password,
        type: 'SuperAdmin'
      )
      user.skip_confirmation!
      user.save!
      puts "✅ Super admin user created: #{user.name} <#{user.email}> (ID: #{user.id})"
    end
    
    user
  end

  def find_or_create_store_admin
    store_admin = User.find_by(email: @store_admin_email)
    
    if store_admin
      puts "👤 Found existing store admin user: #{store_admin.email}"
    else
      puts "👤 Creating store admin user: #{@store_admin_email}"
      store_admin = User.new(
        name: @store_admin_name,
        email: @store_admin_email,
        password: @store_admin_password,
        type: 'User'
      )
      store_admin.skip_confirmation!
      store_admin.save!
      puts "✅ Store admin user created: #{store_admin.name} <#{store_admin.email}> (ID: #{store_admin.id})"
    end
    
    store_admin
  end

  def create_account_user_relationship(account, user)
    account_user = AccountUser.find_by(account: account, user: user)
    
    if account_user
      puts "🔗 Found existing account-user relationship"
    else
      puts "🔗 Creating account-user relationship..."
      AccountUser.create!(
        account_id: account.id,
        user_id: user.id,
        role: :administrator
      )
      puts "✅ Account-user relationship created"
    end
  end


end

# Run seeder if called directly
if __FILE__ == $0
  ProductionSeeder.seed!
end 