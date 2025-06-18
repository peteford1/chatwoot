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
    
    # Create account-user relationship
    create_account_user_relationship(account, user)
    
    # Create default inbox
    create_default_inbox(account, user)
    
    puts "✅ Production seeding completed successfully!"
    puts "📊 Summary:"
    puts "   - Account: #{account.name} (ID: #{account.id})"
    puts "   - Admin User: #{user.name} <#{user.email}> (ID: #{user.id})"
    puts "   - Login URL: #{ENV['FRONTEND_URL'] || 'https://your-chatwoot-domain.com'}"
    puts "   - Email: #{user.email}"
    puts "   - Password: #{@user_password}"
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
      puts "👤 Found existing user: #{user.email}"
    else
      puts "👤 Creating admin user: #{@user_email}"
      user = User.new(
        name: @user_name,
        email: @user_email,
        password: @user_password,
        type: 'SuperAdmin'
      )
      user.skip_confirmation!
      user.save!
      puts "✅ Admin user created: #{user.name} <#{user.email}> (ID: #{user.id})"
    end
    
    user
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

  def create_default_inbox(account, user)
    # Check if account already has inboxes
    if account.inboxes.any?
      puts "📥 Account already has #{account.inboxes.count} inbox(es)"
      return
    end

    puts "📥 Creating default web widget inbox..."
    
    # Create web widget channel
    web_widget = Channel::WebWidget.create!(
      account: account,
      website_url: ENV['FRONTEND_URL'] || 'https://your-chatwoot-domain.com'
    )
    
    # Create inbox
    inbox = Inbox.create!(
      channel: web_widget,
      account: account,
      name: "#{account.name} Support"
    )
    
    # Add admin user to inbox
    InboxMember.create!(user: user, inbox: inbox)
    
    puts "✅ Default inbox created: #{inbox.name} (ID: #{inbox.id})"
  end
end

# Run seeder if called directly
if __FILE__ == $0
  ProductionSeeder.seed!
end 