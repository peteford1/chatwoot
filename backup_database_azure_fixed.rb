#!/usr/bin/env ruby

require 'fileutils'
require 'time'
require 'json'

puts "💾 Starting Azure PostgreSQL Flexible Server Backup (Fixed)..."

# Create timestamp for backup
timestamp = Time.now.to_i
backup_date = Time.now.strftime("%Y%m%d_%H%M%S")

# Backup directory structure
backup_root = "backup"
backup_dir = "#{backup_root}/database_backup_#{timestamp}"

puts "\n📁 Creating backup directory: #{backup_dir}"
FileUtils.mkdir_p(backup_dir)

# Azure database configuration
azure_config = {
  resource_group: "chatwoot-rg",
  server_name: "chatwoot-db-fresh",
  database_name: "chatwoot_production"
}

puts "\n🔗 Azure Database Details:"
puts "   Resource Group: #{azure_config[:resource_group]}"
puts "   Server: #{azure_config[:server_name]}"
puts "   Database: #{azure_config[:database_name]}"

# Create backup info file
backup_info = {
  timestamp: timestamp,
  date: backup_date,
  database: azure_config[:database_name],
  server: azure_config[:server_name],
  resource_group: azure_config[:resource_group],
  backup_type: "azure_flexible_server_backup",
  created_by: "azure_cli_backup_script_fixed",
  reason: "Manual backup requested by user"
}

puts "\n📝 Creating backup metadata..."
File.write("#{backup_dir}/backup_info.json", JSON.pretty_generate(backup_info))

log_file = "#{backup_dir}/backup_log_#{backup_date}.txt"

puts "\n🔍 Checking Azure CLI authentication..."
auth_check = `az account show 2>&1`
if $?.success?
  puts "   ✅ Azure CLI authenticated"
  account_info = JSON.parse(auth_check)
  puts "   📧 Account: #{account_info['user']['name']}"
  puts "   🏢 Subscription: #{account_info['name']}"
else
  puts "   ❌ Azure CLI not authenticated"
  puts "   Please run: az login"
  exit 1
end

puts "\n🚀 Starting Azure flexible server backup..."
start_time = Time.now

# Step 1: List existing backups (with correct parameters)
puts "\n📋 Checking existing backups..."
list_cmd = "az postgres flexible-server backup list -g #{azure_config[:resource_group]} -n #{azure_config[:server_name]} --output json 2>&1 | tee -a #{log_file}"
existing_backups = `#{list_cmd}`

if $?.success?
  begin
    # Filter out non-JSON lines and get the last JSON array
    json_lines = existing_backups.split("\n").select { |line| line.strip.start_with?('[') || line.strip.start_with?('{') }
    if json_lines.any?
      backups = JSON.parse(json_lines.last)
      puts "   ✅ Found #{backups.length} existing backups"
      backups.each_with_index do |backup, index|
        puts "   #{index + 1}. #{backup['name']} (#{backup['backupType']}) - #{backup['completedTime']}"
      end
    else
      puts "   ✅ No existing backups found"
    end
  rescue JSON::ParserError => e
    puts "   ⚠️  Could not parse backup list: #{e.message}"
  end
else
  puts "   ❌ Failed to list existing backups"
end

# Step 2: Create a new backup (with correct parameters)
backup_name = "manual-backup-#{backup_date}"
puts "\n💾 Creating new backup: #{backup_name}"

create_cmd = [
  "az postgres flexible-server backup create",
  "-g #{azure_config[:resource_group]}",
  "-n #{azure_config[:server_name]}",
  "--backup-name #{backup_name}",
  "--output json",
  "2>&1 | tee -a #{log_file}"
].join(" ")

puts "   Command: #{create_cmd.gsub(log_file, '[LOG_FILE]')}"
puts "   ⏳ This may take several minutes..."

backup_result = `#{create_cmd}`
backup_success = $?.success?

end_time = Time.now
duration = (end_time - start_time).round(2)

if backup_success
  puts "\n✅ Azure backup created successfully!"
  puts "   Duration: #{duration} seconds"
  puts "   Backup Name: #{backup_name}"
  
  # Parse backup result
  begin
    result_lines = backup_result.split("\n")
    json_line = result_lines.find { |line| line.strip.start_with?('{') }
    if json_line
      backup_data = JSON.parse(json_line)
      puts "   Backup ID: #{backup_data['id']}"
      puts "   Status: #{backup_data['status'] || 'Created'}"
      puts "   Type: #{backup_data['backupType'] || 'Manual'}"
      
      backup_info[:status] = "success"
      backup_info[:azure_backup_name] = backup_name
      backup_info[:azure_backup_id] = backup_data['id']
      backup_info[:backup_type_azure] = backup_data['backupType']
    else
      puts "   ✅ Backup created (no detailed response)"
      backup_info[:status] = "success"
    end
  rescue JSON::ParserError => e
    puts "   ✅ Backup created (could not parse details: #{e.message})"
    backup_info[:status] = "success_no_details"
  end
  
  backup_info[:duration_seconds] = duration
  backup_info[:azure_backup_name] = backup_name
  
else
  puts "\n❌ Azure backup creation failed!"
  puts "   Duration: #{duration} seconds"
  puts "   Check log file: #{log_file}"
  backup_info[:status] = "failed"
  backup_info[:duration_seconds] = duration
end

# Step 3: Show backup details (with correct parameters)
if backup_success
  puts "\n📊 Getting backup details..."
  show_cmd = "az postgres flexible-server backup show -g #{azure_config[:resource_group]} -n #{azure_config[:server_name]} --backup-name #{backup_name} --output json 2>&1 | tee -a #{log_file}"
  
  backup_details = `#{show_cmd}`
  if $?.success?
    begin
      json_lines = backup_details.split("\n").select { |line| line.strip.start_with?('{') }
      if json_lines.any?
        details = JSON.parse(json_lines.last)
        puts "   📅 Created: #{details['completedTime'] || details['startTime']}"
        puts "   📏 Size: #{details['backupSizeBytes'] ? "#{(details['backupSizeBytes'].to_f / 1024 / 1024).round(2)} MB" : 'Unknown'}"
        puts "   🔄 Status: #{details['status']}"
        
        backup_info[:backup_details] = details
      end
    rescue JSON::ParserError => e
      puts "   ⚠️  Could not parse backup details: #{e.message}"
    end
  end
end

# Update backup info file
File.write("#{backup_dir}/backup_info.json", JSON.pretty_generate(backup_info))

# Create summary
puts "\n📋 Creating backup summary..."
summary = <<~SUMMARY
# Azure PostgreSQL Flexible Server Backup Summary

**Date:** #{Time.now}
**Backup Directory:** #{backup_dir}
**Database:** #{azure_config[:database_name]}
**Server:** #{azure_config[:server_name]}
**Resource Group:** #{azure_config[:resource_group]}
**Status:** #{backup_info[:status]}
**Duration:** #{duration} seconds
**Azure Backup Name:** #{backup_name}

## Files Created:
- #{log_file}
- #{backup_dir}/backup_info.json
- #{backup_dir}/backup_summary.md

## Azure CLI Commands Used:
```bash
# List existing backups
az postgres flexible-server backup list -g #{azure_config[:resource_group]} -n #{azure_config[:server_name]}

# Create new backup
az postgres flexible-server backup create -g #{azure_config[:resource_group]} -n #{azure_config[:server_name]} --backup-name #{backup_name}

# Show backup details
az postgres flexible-server backup show -g #{azure_config[:resource_group]} -n #{azure_config[:server_name]} --backup-name #{backup_name}
```

## Restore Options:
1. **Point-in-time restore:** Create new server from backup
2. **Azure Portal:** Use backup/restore feature
3. **Azure CLI:** Use restore commands

## Restore Command:
```bash
az postgres flexible-server restore \\
  --resource-group #{azure_config[:resource_group]} \\
  --name NEW_SERVER_NAME \\
  --source-server #{azure_config[:server_name]} \\
  --backup-name #{backup_name}
```

## Important Notes:
- This backup is stored in Azure and managed by Azure Database for PostgreSQL
- The backup includes the entire server, not just the specific database
- Retention period depends on your Azure backup policy
- For database-specific exports, use pg_dump with proper network access
SUMMARY

File.write("#{backup_dir}/backup_summary.md", summary)

puts "\n📁 Backup files created in: #{backup_dir}"
puts "   - Log file: #{File.basename(log_file)}"
puts "   - Metadata: backup_info.json"
puts "   - Summary: backup_summary.md"

puts "\n✨ Azure database backup process completed!"

if backup_success
  puts "\n🎉 SUCCESS: Azure backup created successfully"
  puts "   Azure Backup Name: #{backup_name}"
  puts "   Resource Group: #{azure_config[:resource_group]}"
  puts "   Server: #{azure_config[:server_name]}"
  puts "\n💡 To restore this backup:"
  puts "   az postgres flexible-server restore -g #{azure_config[:resource_group]} --name NEW_SERVER_NAME --source-server #{azure_config[:server_name]} --backup-name #{backup_name}"
else
  puts "\n⚠️  FAILED: Check log file for error details"
  puts "   Log: #{log_file}"
  puts "\n💡 Alternative backup options:"
  puts "   1. Use Azure Portal backup/restore feature"
  puts "   2. Create a point-in-time restore"
  puts "   3. Export specific database using pg_dump with proper network access"
end 