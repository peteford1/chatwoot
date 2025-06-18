#!/usr/bin/env ruby

# Account Cleanup Script - AUTOMATED VERSION
# Created: 2025-06-10 08:25:00 PDT
# Purpose: Remove duplicate test accounts created by multiple test scripts
# Preserves only 4 legitimate accounts: Storefront, Test Tenant Account, VoiceLinkAI, Test Account API
# 
# Background: Multiple account creation scripts (create_account22_twilio_inbox.rb, setup_twilio_test.rb)
# created 33+ duplicate accounts with timestamp names and fake generated names
# Legitimate accounts identified via Platform API analysis

require 'net/http'
require 'uri'
require 'json'
require 'fileutils'

# Configuration
API_BASE_URL = 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
PLATFORM_TOKEN = 'YkT9vdgc2UFZ2kgMhPdEaajT'

# Accounts to PRESERVE (legitimate accounts)
PRESERVE_ACCOUNTS = [
  { id: 1, name: 'Storefront' },
  { id: 2, name: 'Test Tenant Account' },
  { id: 10, name: 'Test Account API' },
  { id: 22, name: 'VoiceLinkAI' }
]

# Create backup directory with timestamp
backup_dir = "backup/account_cleanup_#{Time.now.to_i}"
FileUtils.mkdir_p(backup_dir)

puts "🧹 Starting Account Cleanup Process - AUTOMATED MODE"
puts "📅 Date: #{Time.now}"
puts "🎯 Preserving #{PRESERVE_ACCOUNTS.size} legitimate accounts"
puts "📁 Backup directory: #{backup_dir}"
puts ""

def make_api_request(endpoint, method = 'GET', body = nil)
  uri = URI("#{API_BASE_URL}#{endpoint}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  
  request = case method
            when 'GET'
              Net::HTTP::Get.new(uri)
            when 'DELETE'
              Net::HTTP::Delete.new(uri)
            else
              raise "Unsupported method: #{method}"
            end
  
  request['api_access_token'] = PLATFORM_TOKEN
  request['Content-Type'] = 'application/json'
  request.body = body.to_json if body
  
  response = http.request(request)
  
  if response.code.to_i >= 200 && response.code.to_i < 300
    JSON.parse(response.body) rescue response.body
  else
    puts "❌ API Error: #{response.code} - #{response.body}"
    nil
  end
end

def get_all_accounts
  make_api_request('/platform/api/v1/accounts')
end

def delete_account(account_id)
  make_api_request("/platform/api/v1/accounts/#{account_id}", 'DELETE')
end

# Step 1: Get all current accounts and create backup
puts "📋 Step 1: Fetching all accounts..."
all_accounts = get_all_accounts

if all_accounts.nil?
  puts "❌ Failed to fetch accounts. Exiting."
  exit 1
end

puts "📊 Found #{all_accounts.size} total accounts"

# Create backup of current account state
backup_file = "#{backup_dir}/accounts_before_cleanup_#{Time.now.to_i}.json"
File.write(backup_file, JSON.pretty_generate(all_accounts))
puts "💾 Backed up current accounts to: #{backup_file}"

# Step 2: Identify accounts to delete
preserve_ids = PRESERVE_ACCOUNTS.map { |acc| acc[:id] }
accounts_to_delete = all_accounts.reject { |acc| preserve_ids.include?(acc['id']) }

puts ""
puts "🎯 PRESERVATION PLAN:"
PRESERVE_ACCOUNTS.each do |acc|
  found_account = all_accounts.find { |a| a['id'] == acc[:id] }
  if found_account
    puts "  ✅ KEEP: ID #{acc[:id]} - #{acc[:name]}"
  else
    puts "  ⚠️  MISSING: ID #{acc[:id]} - #{acc[:name]} (not found in current accounts)"
  end
end

puts ""
puts "🗑️  DELETION PLAN:"
puts "📊 #{accounts_to_delete.size} accounts will be deleted:"
accounts_to_delete.each do |acc|
  puts "  🔸 DELETE: ID #{acc['id']} - #{acc['name']}"
end

puts ""
puts "⚠️  PROCEEDING AUTOMATICALLY - NO CONFIRMATION REQUIRED"
puts "💾 Backup created at: #{backup_file}"
puts ""

# Step 4: Delete duplicate accounts
puts "🗑️  Starting account deletion..."
deleted_count = 0
failed_deletions = []

accounts_to_delete.each_with_index do |account, index|
  print "Deleting account #{index + 1}/#{accounts_to_delete.size}: ID #{account['id']} - #{account['name']}... "
  
  result = delete_account(account['id'])
  
  if result
    puts "✅ SUCCESS"
    deleted_count += 1
  else
    puts "❌ FAILED"
    failed_deletions << account
  end
  
  # Small delay to avoid overwhelming the API
  sleep(0.5)
end

# Step 5: Verification
puts ""
puts "🔍 Verifying cleanup results..."
remaining_accounts = get_all_accounts

if remaining_accounts
  puts "📊 Accounts remaining: #{remaining_accounts.size}"
  puts ""
  puts "📋 FINAL ACCOUNT LIST:"
  remaining_accounts.each do |acc|
    status = preserve_ids.include?(acc['id']) ? "✅ LEGITIMATE" : "⚠️  UNEXPECTED"
    puts "  #{status}: ID #{acc['id']} - #{acc['name']}"
  end
else
  puts "❌ Failed to verify cleanup results"
end

# Step 6: Summary
puts ""
puts "=" * 60
puts "🎉 CLEANUP SUMMARY"
puts "=" * 60
puts "📊 Total accounts processed: #{all_accounts.size}"
puts "✅ Accounts successfully deleted: #{deleted_count}"
puts "❌ Failed deletions: #{failed_deletions.size}"
puts "🎯 Accounts preserved: #{PRESERVE_ACCOUNTS.size}"
puts "📁 Backup location: #{backup_file}"

if failed_deletions.any?
  puts ""
  puts "⚠️  FAILED DELETIONS:"
  failed_deletions.each do |acc|
    puts "  🔸 ID #{acc['id']} - #{acc['name']}"
  end
end

puts ""
puts "✨ Account cleanup completed!"
puts "📅 Finished at: #{Time.now}" 