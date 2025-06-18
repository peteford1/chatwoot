#!/usr/bin/env ruby

# Advanced SyncAccounts Test Script
# Created: 2025-06-10 14:00:00
# Purpose: Test complex user synchronization scenarios with username handling
# Description: Tests existing users, non-existent users, and username-based lookups

require 'net/http'
require 'json'
require 'uri'

class AdvancedSyncAccountsTester
  def initialize(base_url = 'http://localhost:3000')
    @base_url = base_url
    @account_id = 1  # Default to account 1 for testing
    @test_users = []
    @created_users = []
  end

  def run_all_tests
    puts "🧪 Advanced SyncAccounts Service Testing"
    puts "========================================"
    puts "Base URL: #{@base_url}"
    puts "Account ID: #{@account_id}"
    puts ""

    # Setup test data
    setup_test_users
    
    # Run tests in sequence
    test_health_check
    test_scenario_1_new_users
    test_scenario_2_existing_users_same_id
    test_scenario_3_wrong_chatwoot_id_correct_username
    test_scenario_4_mixed_scenarios
    test_scenario_5_username_conflicts
    
    # Cleanup
    cleanup_test_users

    puts ""
    puts "✅ All advanced tests completed!"
  end

  private

  def setup_test_users
    puts "🔧 Setting up test data..."
    
    @test_users = [
      {
        sm_user_id: "test_user_001",
        name: "Alice Johnson",
        username: "alice.johnson",
        chatwoot_user_id: nil,
        scenario: "new_user"
      },
      {
        sm_user_id: "test_user_002", 
        name: "Bob Smith",
        username: "bob.smith",
        chatwoot_user_id: nil,
        scenario: "new_user_to_be_existing"
      },
      {
        sm_user_id: "test_user_003",
        name: "Charlie Brown",
        username: "charlie.brown", 
        chatwoot_user_id: nil,
        scenario: "username_lookup"
      },
      {
        sm_user_id: "test_user_004",
        name: "Diana Prince",
        username: "diana.prince",
        chatwoot_user_id: 99999, # Non-existent ID
        scenario: "wrong_id_correct_username"
      }
    ]
    
    puts "   📊 Test users prepared: #{@test_users.length}"
    puts ""
  end

  def test_health_check
    puts "1. Testing Health Check..."
    
    response = make_request(:get, "/api/v1/accounts/#{@account_id}/sync_accounts/health")
    
    if response[:success]
      puts "   ✅ Health check passed"
      puts "   📊 Status: #{response[:data]['status']}"
    else
      puts "   ❌ Health check failed: #{response[:error]}"
    end
    
    puts ""
  end

  def test_scenario_1_new_users
    puts "2. Testing Scenario 1: New Users Creation..."
    puts "   📝 Creating users that don't exist in Chatwoot"
    
    new_users = @test_users.select { |u| u[:scenario] == "new_user" }
    
    test_data = {
      sync_accounts: {
        sm_store_id: "test_store_new_users",
        store_name: "Test Store - New Users",
        chatwoot_account_id: @account_id,
        users: new_users.map { |u| u.slice(:sm_user_id, :name, :username, :chatwoot_user_id) }
      }
    }
    
    response = make_request(:post, "/api/v1/accounts/#{@account_id}/sync_accounts/sync", test_data)
    
    if response[:success]
      data = response[:data]
      puts "   ✅ New users sync completed"
      puts "   📊 Total users: #{data['summary']['total_users']}"
      puts "   📊 Changed users: #{data['summary']['changed_users']} (should equal total)"
      puts "   📊 Errors: #{data['summary']['errors']}"
      
      # Store created user IDs for subsequent tests
      data['users'].each do |user|
        if user['changed_flag']
          @created_users << {
            sm_user_id: user['sm_user_id'],
            username: user['username'],
            chatwoot_user_id: user['chatwoot_user_id']
          }
          puts "   👤 #{user['name']} (#{user['username']}): ID=#{user['chatwoot_user_id']}, Changed=#{user['changed_flag']}"
        end
      end
    else
      puts "   ❌ New users sync failed: #{response[:error]}"
    end
    
    puts ""
  end

  def test_scenario_2_existing_users_same_id
    puts "3. Testing Scenario 2: Existing Users with Same ID..."
    puts "   📝 Syncing users that already exist with correct chatwoot_user_id"
    
    if @created_users.empty?
      puts "   ⚠️  Skipping - no users created in previous test"
      puts ""
      return
    end
    
    # Use created users with their actual IDs
    existing_users = @created_users.map do |user|
      {
        sm_user_id: user[:sm_user_id],
        name: "#{user[:sm_user_id].split('_').last.capitalize} Updated", # Change name slightly
        username: user[:username],
        chatwoot_user_id: user[:chatwoot_user_id]
      }
    end
    
    test_data = {
      sync_accounts: {
        sm_store_id: "test_store_existing",
        store_name: "Test Store - Existing Users",
        chatwoot_account_id: @account_id,
        users: existing_users
      }
    }
    
    response = make_request(:post, "/api/v1/accounts/#{@account_id}/sync_accounts/sync", test_data)
    
    if response[:success]
      data = response[:data]
      puts "   ✅ Existing users sync completed"
      puts "   📊 Total users: #{data['summary']['total_users']}"
      puts "   📊 Changed users: #{data['summary']['changed_users']} (should be 0 for ID, but may be >0 for name updates)"
      puts "   📊 Errors: #{data['summary']['errors']}"
      
      data['users'].each do |user|
        puts "   👤 #{user['name']} (#{user['username']}): ID=#{user['chatwoot_user_id']}, Changed=#{user['changed_flag']}"
      end
    else
      puts "   ❌ Existing users sync failed: #{response[:error]}"
    end
    
    puts ""
  end

  def test_scenario_3_wrong_chatwoot_id_correct_username
    puts "4. Testing Scenario 3: Wrong chatwoot_user_id but Correct Username..."
    puts "   📝 Sending wrong chatwoot_user_id but username that exists in account"
    
    if @created_users.empty?
      puts "   ⚠️  Skipping - no users created in previous test"
      puts ""
      return
    end
    
    # Take first created user and give it a wrong ID but correct username
    test_user = @created_users.first
    wrong_id_users = [{
      sm_user_id: test_user[:sm_user_id],
      name: "Updated Name for Wrong ID Test",
      username: test_user[:username],
      chatwoot_user_id: 99999 # Wrong ID
    }]
    
    test_data = {
      sync_accounts: {
        sm_store_id: "test_store_wrong_id",
        store_name: "Test Store - Wrong ID Lookup",
        chatwoot_account_id: @account_id,
        users: wrong_id_users
      }
    }
    
    response = make_request(:post, "/api/v1/accounts/#{@account_id}/sync_accounts/sync", test_data)
    
    if response[:success]
      data = response[:data]
      puts "   ✅ Wrong ID lookup completed"
      puts "   📊 Total users: #{data['summary']['total_users']}"
      puts "   📊 Changed users: #{data['summary']['changed_users']} (should be 1 - ID corrected)"
      puts "   📊 Errors: #{data['summary']['errors']}"
      
      data['users'].each do |user|
        puts "   👤 #{user['name']} (#{user['username']}): ID=#{user['chatwoot_user_id']}, Changed=#{user['changed_flag']}"
        if user['changed_flag'] && user['chatwoot_user_id'] == test_user[:chatwoot_user_id]
          puts "   ✅ Correct ID found via username lookup!"
        end
      end
    else
      puts "   ❌ Wrong ID lookup failed: #{response[:error]}"
    end
    
    puts ""
  end

  def test_scenario_4_mixed_scenarios
    puts "5. Testing Scenario 4: Mixed User Scenarios..."
    puts "   📝 Combining new users, existing users, and wrong ID lookups"
    
    mixed_users = []
    
    # Add a new user
    mixed_users << {
      sm_user_id: "test_user_mixed_new",
      name: "Mixed Test New User",
      username: "mixed.new.user",
      chatwoot_user_id: nil
    }
    
    # Add an existing user if available
    if @created_users.any?
      existing_user = @created_users.first
      mixed_users << {
        sm_user_id: existing_user[:sm_user_id],
        name: "Mixed Test Existing User",
        username: existing_user[:username], 
        chatwoot_user_id: existing_user[:chatwoot_user_id]
      }
    end
    
    # Add a wrong ID user if available
    if @created_users.length > 1
      wrong_id_user = @created_users.last
      mixed_users << {
        sm_user_id: wrong_id_user[:sm_user_id],
        name: "Mixed Test Wrong ID User",
        username: wrong_id_user[:username],
        chatwoot_user_id: 88888 # Wrong ID
      }
    end
    
    test_data = {
      sync_accounts: {
        sm_store_id: "test_store_mixed",
        store_name: "Test Store - Mixed Scenarios",
        chatwoot_account_id: @account_id,
        users: mixed_users
      }
    }
    
    response = make_request(:post, "/api/v1/accounts/#{@account_id}/sync_accounts/sync", test_data)
    
    if response[:success]
      data = response[:data]
      puts "   ✅ Mixed scenarios sync completed"
      puts "   📊 Total users: #{data['summary']['total_users']}"
      puts "   📊 Changed users: #{data['summary']['changed_users']}"
      puts "   📊 Errors: #{data['summary']['errors']}"
      
      data['users'].each do |user|
        puts "   👤 #{user['name']} (#{user['username']}): ID=#{user['chatwoot_user_id']}, Changed=#{user['changed_flag']}"
      end
    else
      puts "   ❌ Mixed scenarios sync failed: #{response[:error]}"
    end
    
    puts ""
  end

  def test_scenario_5_username_conflicts
    puts "6. Testing Scenario 5: Username Conflict Handling..."
    puts "   📝 Testing edge cases with username conflicts and lookups"
    
    conflict_users = [
      {
        sm_user_id: "test_user_conflict_1",
        name: "Conflict User One",
        username: "conflict.user", 
        chatwoot_user_id: nil
      },
      {
        sm_user_id: "test_user_conflict_2",
        name: "Conflict User Two",
        username: "conflict.user", # Same username
        chatwoot_user_id: nil
      }
    ]
    
    test_data = {
      sync_accounts: {
        sm_store_id: "test_store_conflicts",
        store_name: "Test Store - Username Conflicts",
        chatwoot_account_id: @account_id,
        users: conflict_users
      }
    }
    
    response = make_request(:post, "/api/v1/accounts/#{@account_id}/sync_accounts/sync", test_data)
    
    if response[:success]
      data = response[:data]
      puts "   ✅ Username conflicts handled"
      puts "   📊 Total users: #{data['summary']['total_users']}"
      puts "   📊 Changed users: #{data['summary']['changed_users']}"
      puts "   📊 Errors: #{data['summary']['errors']}"
      
      data['users'].each do |user|
        if user['error']
          puts "   ❌ #{user['name']} (#{user['username']}): ERROR - #{user['error']}"
        else
          puts "   👤 #{user['name']} (#{user['username']}): ID=#{user['chatwoot_user_id']}, Changed=#{user['changed_flag']}"
        end
      end
    else
      puts "   ❌ Username conflicts test failed: #{response[:error]}"
    end
    
    puts ""
  end

  def cleanup_test_users
    puts "🧹 Cleanup completed (test users remain for inspection)"
    puts "   📝 Created #{@created_users.length} test users during testing"
    @created_users.each do |user|
      puts "   👤 #{user[:username]} (ID: #{user[:chatwoot_user_id]})"
    end
    puts ""
  end

  def make_request(method, path, data = nil)
    begin
      uri = URI("#{@base_url}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = 10
      http.read_timeout = 30
      
      case method
      when :get
        request = Net::HTTP::Get.new(uri)
      when :post
        request = Net::HTTP::Post.new(uri)
        request['Content-Type'] = 'application/json'
        request.body = data.to_json if data
      end
      
      response = http.request(request)
      
      {
        success: response.code.to_i.between?(200, 299),
        status: response.code.to_i,
        data: JSON.parse(response.body),
        error: response.code.to_i.between?(200, 299) ? nil : "HTTP #{response.code}: #{response.message}"
      }
      
    rescue JSON::ParserError => e
      {
        success: false,
        status: 0,
        data: nil,
        error: "JSON Parse Error: #{e.message}"
      }
    rescue => e
      {
        success: false,
        status: 0,
        data: nil,
        error: "Request Error: #{e.class} - #{e.message}"
      }
    end
  end
end

# Test Data Generator
class TestDataGenerator
  def self.generate_comprehensive_test_data(account_id)
    {
      sync_accounts: {
        sm_store_id: "comprehensive_test_#{Time.now.to_i}",
        store_name: "Comprehensive Test Store",
        chatwoot_account_id: account_id,
        users: [
          # Scenario 1: New user (null chatwoot_user_id)
          {
            sm_user_id: "new_user_001",
            name: "New User One",
            username: "new.user.one",
            chatwoot_user_id: nil
          },
          
          # Scenario 2: New user (empty chatwoot_user_id)
          {
            sm_user_id: "new_user_002", 
            name: "New User Two",
            username: "new.user.two",
            chatwoot_user_id: ""
          },
          
          # Scenario 3: Existing user with correct ID (will be filled after creation)
          # {
          #   sm_user_id: "existing_user_001",
          #   name: "Existing User One",
          #   username: "existing.user.one",
          #   chatwoot_user_id: 123 # This would be filled with actual ID
          # },
          
          # Scenario 4: Wrong chatwoot_user_id but correct username
          {
            sm_user_id: "wrong_id_user",
            name: "Wrong ID User",
            username: "wrong.id.user",
            chatwoot_user_id: 99999 # Non-existent ID, but username will be created first
          }
        ]
      }
    }
  end
end

# Usage examples
if __FILE__ == $0
  puts "Advanced SyncAccounts Service Tester"
  puts "===================================="
  puts ""
  
  # Parse command line arguments
  base_url = ARGV[0] || 'http://localhost:3000'
  
  if ARGV.include?('--help') || ARGV.include?('-h')
    puts "Usage: ruby test_sync_accounts_advanced.rb [BASE_URL]"
    puts ""
    puts "Arguments:"
    puts "  BASE_URL    Base URL of the Chatwoot instance (default: http://localhost:3000)"
    puts ""
    puts "Test Scenarios:"
    puts "  1. New users creation (null/empty chatwoot_user_id)"
    puts "  2. Existing users with same ID (no changes expected)"
    puts "  3. Wrong chatwoot_user_id but correct username (ID correction)"
    puts "  4. Mixed scenarios (combination of above)"
    puts "  5. Username conflicts and edge cases"
    puts ""
    puts "Examples:"
    puts "  ruby test_sync_accounts_advanced.rb"
    puts "  ruby test_sync_accounts_advanced.rb https://your-domain.com"
    puts "  ruby test_sync_accounts_advanced.rb https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
    exit 0
  end
  
  tester = AdvancedSyncAccountsTester.new(base_url)
  tester.run_all_tests
end 