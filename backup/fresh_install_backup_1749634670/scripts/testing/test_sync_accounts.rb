#!/usr/bin/env ruby

# SyncAccounts Test Script
# Created: 2025-06-10 13:30:00
# Purpose: Test the SyncAccounts web service with sample data
# Description: Demonstrates service functionality and validates responses

require 'net/http'
require 'json'
require 'uri'

class SyncAccountsTester
  def initialize(base_url = 'http://localhost:3000')
    @base_url = base_url
    @account_id = 1  # Default to account 1 for testing
  end

  def run_all_tests
    puts "🧪 SyncAccounts Service Testing"
    puts "================================"
    puts "Base URL: #{@base_url}"
    puts "Account ID: #{@account_id}"
    puts ""

    test_health_check
    test_service_info
    test_sync_new_users
    test_sync_existing_users
    test_error_handling

    puts ""
    puts "✅ All tests completed!"
  end

  private

  def test_health_check
    puts "1. Testing Health Check..."
    
    response = make_request(:get, "/api/v1/accounts/#{@account_id}/sync_accounts/health")
    
    if response[:success]
      puts "   ✅ Health check passed"
      puts "   📊 Status: #{response[:data]['status']}"
      puts "   📊 Version: #{response[:data]['version']}"
    else
      puts "   ❌ Health check failed: #{response[:error]}"
    end
    
    puts ""
  end

  def test_service_info
    puts "2. Testing Service Info..."
    
    response = make_request(:get, "/api/v1/accounts/#{@account_id}/sync_accounts/info")
    
    if response[:success]
      puts "   ✅ Service info retrieved"
      puts "   📊 Service: #{response[:data]['service']}"
      puts "   📊 Description: #{response[:data]['description']}"
    else
      puts "   ❌ Service info failed: #{response[:error]}"
    end
    
    puts ""
  end

  def test_sync_new_users
    puts "3. Testing Sync with New Users..."
    
    test_data = {
      sync_accounts: {
        sm_store_id: "test_store_#{Time.now.to_i}",
        store_name: "Test Store - New Users",
        chatwoot_account_id: @account_id,
        users: [
          {
            sm_user_id: "test_user_001",
            name: "Alice Johnson",
            chatwoot_user_id: nil
          },
          {
            sm_user_id: "test_user_002", 
            name: "Bob Smith",
            chatwoot_user_id: nil
          }
        ]
      }
    }
    
    response = make_request(:post, "/api/v1/accounts/#{@account_id}/sync_accounts/sync", test_data)
    
    if response[:success]
      data = response[:data]
      puts "   ✅ Sync completed successfully"
      puts "   📊 Account changed: #{data['account_changed']}"
      puts "   📊 Total users: #{data['summary']['total_users']}"
      puts "   📊 Changed users: #{data['summary']['changed_users']}"
      puts "   📊 Errors: #{data['summary']['errors']}"
      
      # Show user details
      data['users'].each do |user|
        puts "   👤 #{user['name']}: ID=#{user['chatwoot_user_id']}, Changed=#{user['changed_flag']}"
      end
    else
      puts "   ❌ Sync failed: #{response[:error]}"
    end
    
    puts ""
  end

  def test_sync_existing_users
    puts "4. Testing Sync with Existing Users..."
    
    # First, get existing users from previous test
    existing_users = get_sample_existing_users
    
    if existing_users.any?
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
        puts "   ✅ Existing user sync completed"
        puts "   📊 Changed users: #{data['summary']['changed_users']} (should be 0)"
      else
        puts "   ❌ Existing user sync failed: #{response[:error]}"
      end
    else
      puts "   ⚠️  Skipping - no existing users found"
    end
    
    puts ""
  end

  def test_error_handling
    puts "5. Testing Error Handling..."
    
    # Test missing required fields
    puts "   Testing validation errors..."
    
    invalid_data = {
      sync_accounts: {
        sm_store_id: "test",
        # Missing store_name and chatwoot_account_id
        users: []
      }
    }
    
    response = make_request(:post, "/api/v1/accounts/#{@account_id}/sync_accounts/sync", invalid_data)
    
    if !response[:success] && response[:status] == 400
      puts "   ✅ Validation error handled correctly"
      puts "   📊 Error: #{response[:error]}"
    else
      puts "   ❌ Validation error not handled properly"
    end
    
    # Test invalid account ID
    puts "   Testing invalid account..."
    
    valid_data = {
      sync_accounts: {
        sm_store_id: "test",
        store_name: "Test",
        chatwoot_account_id: 99999,  # Non-existent account
        users: [
          {
            sm_user_id: "test",
            name: "Test User"
          }
        ]
      }
    }
    
    response = make_request(:post, "/api/v1/accounts/99999/sync_accounts/sync", valid_data)
    
    if !response[:success] && [404, 500].include?(response[:status])
      puts "   ✅ Invalid account handled correctly"
      puts "   📊 Error: #{response[:error]}"
    else
      puts "   ❌ Invalid account not handled properly"
    end
    
    puts ""
  end

  def get_sample_existing_users
    # This would typically query the database or previous responses
    # For demo purposes, return sample data that should exist
    [
      {
        sm_user_id: "test_user_001",
        name: "Alice Johnson Updated",  # Changed name to test updates
        chatwoot_user_id: 1  # Assuming user ID 1 exists
      }
    ]
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

# Usage examples
if __FILE__ == $0
  puts "SyncAccounts Service Tester"
  puts "==========================="
  puts ""
  
  # Parse command line arguments
  base_url = ARGV[0] || 'http://localhost:3000'
  
  if ARGV.include?('--help') || ARGV.include?('-h')
    puts "Usage: ruby test_sync_accounts.rb [BASE_URL]"
    puts ""
    puts "Arguments:"
    puts "  BASE_URL    Base URL of the Chatwoot instance (default: http://localhost:3000)"
    puts ""
    puts "Examples:"
    puts "  ruby test_sync_accounts.rb"
    puts "  ruby test_sync_accounts.rb https://your-domain.com"
    puts "  ruby test_sync_accounts.rb https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
    exit 0
  end
  
  tester = SyncAccountsTester.new(base_url)
  tester.run_all_tests
end 