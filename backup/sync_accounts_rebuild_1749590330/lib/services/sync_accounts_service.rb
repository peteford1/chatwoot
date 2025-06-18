# SyncAccounts Service
# Created: 2025-06-10 13:10:00
# Purpose: Synchronize users between external system and Chatwoot accounts
# Description: Creates/updates users, manages roles, and assigns to inboxes

require_relative '../utilities/logger'

class SyncAccountsService
  include CustomUtilities::Logger

  attr_reader :account_changed, :users_processed

  def initialize
    @account_changed = false
    @users_processed = []
    log_info("SyncAccountsService initialized")
  end

  # Main service method
  # @param sync_data [Hash] Input data with sm_store_id, store_name, chatwoot_account_id, users array
  # @return [Hash] Response with original structure plus changed flags
  def sync_accounts(sync_data)
    log_info("Starting sync_accounts", sync_data.slice(:sm_store_id, :store_name, :chatwoot_account_id))
    
    begin
      validate_input(sync_data)
      
      account = find_or_validate_account(sync_data[:chatwoot_account_id])
      update_account_if_needed(account, sync_data[:store_name])
      
      process_users(account, sync_data[:users])
      assign_users_to_inboxes(account)
      
      build_response(sync_data)
      
    rescue => e
      log_error("Error in sync_accounts", e)
      raise e
    end
  end

  private

  def validate_input(data)
    required_fields = [:sm_store_id, :store_name, :chatwoot_account_id, :users]
    missing_fields = required_fields.select { |field| data[field].nil? }
    
    if missing_fields.any?
      raise ArgumentError, "Missing required fields: #{missing_fields.join(', ')}"
    end

    unless data[:users].is_a?(Array)
      raise ArgumentError, "Users must be an array"
    end

    data[:users].each_with_index do |user, index|
      user_required = [:sm_user_id, :name, :username]
      user_missing = user_required.select { |field| user[field].nil? || user[field].to_s.strip.empty? }
      
      if user_missing.any?
        raise ArgumentError, "User at index #{index} missing required fields: #{user_missing.join(', ')}"
      end
    end

    log_info("Input validation passed")
  end

  def find_or_validate_account(chatwoot_account_id)
    account = Account.find_by(id: chatwoot_account_id)
    
    unless account
      raise ArgumentError, "Chatwoot account with ID #{chatwoot_account_id} not found"
    end

    log_info("Found account", { id: account.id, name: account.name })
    account
  end

  def update_account_if_needed(account, new_store_name)
    if account.name != new_store_name
      log_info("Updating account name", { 
        old_name: account.name, 
        new_name: new_store_name 
      })
      
      account.update!(name: new_store_name)
      @account_changed = true
    end
  end

  def process_users(account, users_data)
    users_data.each do |user_data|
      result = process_single_user(account, user_data)
      @users_processed << result
    end
  end

  def process_single_user(account, user_data)
    log_info("Processing user", user_data.slice(:sm_user_id, :name, :username, :chatwoot_user_id))
    
    user_result = user_data.dup
    user_result[:changed_flag] = false
    
    begin
      user = find_or_create_user(account, user_data)
      account_user = ensure_user_in_account(account, user)
      ensure_administrator_role(account_user)
      
      # Check if chatwoot_user_id changed
      if user_data[:chatwoot_user_id].blank? || user_data[:chatwoot_user_id] != user.id
        user_result[:chatwoot_user_id] = user.id
        user_result[:changed_flag] = true
        log_info("User chatwoot_user_id updated", { 
          sm_user_id: user_data[:sm_user_id],
          username: user_data[:username],
          old_id: user_data[:chatwoot_user_id],
          new_id: user.id 
        })
      end
      
    rescue => e
      log_error("Error processing user #{user_data[:sm_user_id]}", e)
      user_result[:error] = e.message
    end
    
    user_result
  end

  def find_or_create_user(account, user_data)
    user = nil
    
    # Try to find existing user by chatwoot_user_id
    if user_data[:chatwoot_user_id].present?
      user = User.find_by(id: user_data[:chatwoot_user_id])
      
      if user
        # Check if user is actually in this account
        account_user = user.account_users.find_by(account: account)
        
        if account_user
          log_info("Found existing user by chatwoot_user_id", { id: user.id, email: user.email })
          
          # Reactivate if inactive
          if account_user.inactive?
            reactivate_user(user, account.id)
          end
          
          # Update name and username if different
          update_user_details(user, user_data)
          
          return user
        else
          log_info("chatwoot_user_id exists but not in this account, trying username lookup", {
            chatwoot_user_id: user_data[:chatwoot_user_id],
            username: user_data[:username],
            account_id: account.id
          })
        end
      else
        log_info("chatwoot_user_id not found, trying username lookup", {
          chatwoot_user_id: user_data[:chatwoot_user_id],
          username: user_data[:username]
        })
      end
    end
    
    # Try to find by username within the account
    if user_data[:username].present?
      user = find_user_by_username_in_account(account, user_data[:username])
      
      if user
        log_info("Found existing user by username in account", { 
          id: user.id, 
          email: user.email,
          username: user_data[:username] 
        })
        
        # Update user details
        update_user_details(user, user_data)
        
        return user
      end
    end
    
    # Try to find by email (construct from sm_user_id)
    email = construct_email(user_data[:sm_user_id])
    user = User.find_by(email: email)
    
    if user
      log_info("Found existing user by email", { id: user.id, email: user.email })
      update_user_details(user, user_data)
      return user
    end
    
    # Create new user
    create_new_user(user_data)
  end

  def construct_email(sm_user_id)
    # Create email from sm_user_id - adjust this logic as needed
    "user_#{sm_user_id}@voicelinkai.com"
  end

  def find_user_by_username_in_account(account, username)
    # Find user by email (assuming username is used as email prefix)
    email_pattern = "#{username}@%"
    
    # First try exact username as email prefix
    users_by_email = User.joins(:account_users)
                        .where(account_users: { account: account })
                        .where("email LIKE ?", email_pattern)
    
    return users_by_email.first if users_by_email.exists?
    
    # Try finding by display_name or custom_attributes if available
    users_by_name = User.joins(:account_users)
                       .where(account_users: { account: account })
                       .where("name ILIKE ? OR email ILIKE ?", "%#{username}%", "%#{username}%")
    
    users_by_name.first
  end

  def update_user_details(user, user_data)
    updates = {}
    
    # Update name if different
    if user.name != user_data[:name]
      updates[:name] = user_data[:name]
      log_info("Updating user name", { 
        id: user.id, 
        old_name: user.name, 
        new_name: user_data[:name] 
      })
    end
    
    # Update email if username changed (construct new email)
    new_email = "#{user_data[:username]}@voicelinkai.com"
    if user.email != new_email
      # Check if new email is available
      unless User.where(email: new_email).where.not(id: user.id).exists?
        updates[:email] = new_email
        log_info("Updating user email", { 
          id: user.id, 
          old_email: user.email, 
          new_email: new_email 
        })
      end
    end
    
    # Apply updates if any
    if updates.any?
      user.update!(updates)
      log_info("User details updated", { id: user.id, updates: updates })
    end
  end

  def create_new_user(user_data)
    email = "#{user_data[:username]}@voicelinkai.com"
    password = SecureRandom.hex(12)
    
    user = User.create!(
      name: user_data[:name],
      email: email,
      password: password,
      password_confirmation: password,
      confirmed_at: Time.current
    )
    
    log_info("Created new user", { 
      id: user.id, 
      email: user.email, 
      name: user.name,
      username: user_data[:username],
      sm_user_id: user_data[:sm_user_id]
    })
    
    user
  end

  def reactivate_user(user, account_id)
    account_user = user.account_users.find_by(account_id: account_id)
    
    if account_user&.inactive?
      account_user.update!(status: 'active')
      log_info("Reactivated user", { user_id: user.id, account_id: account_id })
    end
  end

  def ensure_user_in_account(account, user)
    account_user = AccountUser.find_or_create_by(account: account, user: user) do |au|
      au.role = 'administrator'
      au.status = 'active'
      log_info("Added user to account", { 
        user_id: user.id, 
        account_id: account.id,
        role: 'administrator'
      })
    end
    
    account_user
  end

  def ensure_administrator_role(account_user)
    if account_user.role != 'administrator'
      account_user.update!(role: 'administrator')
      log_info("Updated user role to administrator", { 
        user_id: account_user.user_id,
        account_id: account_user.account_id
      })
    end
  end

  def assign_users_to_inboxes(account)
    inboxes = account.inboxes.where(channel_type: ['Channel::WebWidget', 'Channel::Api', 'Channel::TwilioSms'])
    active_users = account.users.joins(:account_users)
                              .where(account_users: { status: 'active' })
    
    log_info("Assigning users to inboxes", { 
      account_id: account.id,
      inbox_count: inboxes.count,
      user_count: active_users.count
    })
    
    inboxes.each do |inbox|
      active_users.each do |user|
        # Add user to inbox if not already assigned
        unless inbox.members.include?(user)
          inbox.add_member(user.id)
          log_info("Added user to inbox", { 
            user_id: user.id,
            inbox_id: inbox.id,
            inbox_name: inbox.name
          })
        end
      end
    end
  end

  def build_response(sync_data)
    response = {
      sm_store_id: sync_data[:sm_store_id],
      store_name: sync_data[:store_name],
      chatwoot_account_id: sync_data[:chatwoot_account_id],
      account_changed: @account_changed,
      users: @users_processed,
      processed_at: Time.current.iso8601,
      summary: {
        total_users: @users_processed.length,
        changed_users: @users_processed.count { |u| u[:changed_flag] },
        errors: @users_processed.count { |u| u[:error].present? }
      }
    }
    
    log_info("Sync completed", response[:summary])
    response
  end
end 