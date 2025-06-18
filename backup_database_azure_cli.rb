#!/usr/bin/env ruby

require 'fileutils'
require 'time'
require 'json'

puts "💾 Starting Azure Database Backup Process..."

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
  database_name: "chatwoot_production",
  subscription: nil # Will be detected automatically
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
  backup_type: "azure_postgres_backup",
  created_by: "azure_cli_backup_script",
  reason: "Manual backup requested by user"
}

puts "\n📝 Creating backup metadata..."
File.write("#{backup_dir}/backup_info.json", JSON.pretty_generate(backup_info))

# Create backup files
backup_file = "#{backup_dir}/chatwoot_production_#{backup_date}.bacpac"
log_file = "#{backup_dir}/backup_log_#{backup_date}.txt"

puts "\n🔍 Checking Azure CLI authentication..."
auth_check = `az account show 2>&1`
if $?.success?
  puts "   ✅ Azure CLI authenticated"
  account_info = JSON.parse(auth_check)
  puts "   📧 Account: #{account_info['user']['name']}"
  puts "   🏢 Subscription: #{account_info['name']}"
  azure_config[:subscription] = account_info['id']
else
  puts "   ❌ Azure CLI not authenticated"
  puts "   Please run: az login"
  exit 1
end

puts "\n🚀 Starting Azure database backup..."
puts "   Method: Azure PostgreSQL export"
puts "   Output file: #{backup_file}"
puts "   Log file: #{log_file}"

# Create the Azure CLI backup command
# Note: Azure PostgreSQL doesn't have direct backup export like SQL Server
# We'll use pg_dump through Azure CLI with proper authentication

backup_cmd = [
  "az postgres db export",
  "--resource-group #{azure_config[:resource_group]}",
  "--server-name #{azure_config[:server_name]}",
  "--name #{azure_config[:database_name]}",
  "--backup-file #{backup_file}",
  "--verbose",
  "2>&1 | tee #{log_file}"
].join(" ")

puts "\n⏳ This may take several minutes for large databases..."
start_time = Time.now

# Try the backup command
success = system(backup_cmd)

# If that doesn't work, try alternative approach with pg_dump via Azure
if !success
  puts "\n🔄 Trying alternative backup method..."
  
  # Get connection string from Azure
  puts "   Getting database connection details..."
  conn_cmd = "az postgres server show --resource-group #{azure_config[:resource_group]} --name #{azure_config[:server_name]} --output json"
  server_info = `#{conn_cmd}`
  
  if $?.success?
    server_data = JSON.parse(server_info)
    host = server_data['fullyQualifiedDomainName']
    
    puts "   Host: #{host}"
    
    # Create pg_dump command with Azure authentication
    dump_file = "#{backup_dir}/chatwoot_production_#{backup_date}.sql"
    
    # Try to get admin credentials or use managed identity
    pg_dump_cmd = [
      "pg_dump",
      "--host=#{host}",
      "--port=5432",
      "--username=chatwoot_prod",
      "--dbname=#{azure_config[:database_name]}",
      "--verbose",
      "--clean",
      "--if-exists",
      "--create",
      "--format=plain",
      "--file=#{dump_file}",
      "2>&1 | tee #{log_file}"
    ].join(" ")
    
    puts "   Trying pg_dump with Azure host..."
    ENV['PGPASSWORD'] = 'chatwoot_prod'  # You may need to update this
    success = system(pg_dump_cmd)
    ENV.delete('PGPASSWORD')
    
    backup_file = dump_file if success
  end
end

end_time = Time.now
duration = (end_time - start_time).round(2)

if success
  puts "\n✅ Database backup completed successfully!"
  puts "   Duration: #{duration} seconds"
  
  # Check file size
  if File.exist?(backup_file)
    file_size = File.size(backup_file)
    file_size_mb = (file_size / 1024.0 / 1024.0).round(2)
    puts "   Backup size: #{file_size_mb} MB"
    
    # Update backup info with results
    backup_info[:status] = "success"
    backup_info[:duration_seconds] = duration
    backup_info[:file_size_bytes] = file_size
    backup_info[:file_size_mb] = file_size_mb
    backup_info[:backup_file] = backup_file
  else
    puts "   ⚠️  Warning: Backup file not found after export"
    backup_info[:status] = "completed_but_file_missing"
  end
else
  puts "\n❌ Database backup failed!"
  puts "   Check the log file for details: #{log_file}"
  backup_info[:status] = "failed"
  backup_info[:duration_seconds] = duration
end

# Update backup info file
File.write("#{backup_dir}/backup_info.json", JSON.pretty_generate(backup_info))

# Create a quick reference file
puts "\n📋 Creating backup summary..."
summary = <<~SUMMARY
# Azure Database Backup Summary
Date: #{Time.now}
Backup Directory: #{backup_dir}
Database: #{azure_config[:database_name]}
Server: #{azure_config[:server_name]}
Resource Group: #{azure_config[:resource_group]}
Status: #{backup_info[:status]}
Duration: #{duration} seconds
#{backup_info[:file_size_mb] ? "Size: #{backup_info[:file_size_mb]} MB" : ""}

## Files Created:
- #{backup_file}
- #{log_file}
- #{backup_dir}/backup_info.json
- #{backup_dir}/backup_summary.md

## Azure CLI Commands Used:
az postgres db export --resource-group #{azure_config[:resource_group]} --server-name #{azure_config[:server_name]} --name #{azure_config[:database_name]}

## Alternative Restore Methods:
1. Azure Portal: Import/Export feature
2. pg_restore: pg_restore -h #{azure_config[:server_name]}.postgres.database.azure.com -U chatwoot_prod -d #{azure_config[:database_name]} #{backup_file}
3. Azure CLI: az postgres db import
SUMMARY

File.write("#{backup_dir}/backup_summary.md", summary)

puts "\n📁 Backup files created in: #{backup_dir}"
puts "   - Backup file: #{File.basename(backup_file)}"
puts "   - Log file: #{File.basename(log_file)}"
puts "   - Metadata: backup_info.json"
puts "   - Summary: backup_summary.md"

puts "\n✨ Azure database backup process completed!"

if success
  puts "\n🎉 SUCCESS: Database backup is ready for use"
  puts "   Location: #{backup_file}"
else
  puts "\n⚠️  FAILED: Check log file for error details"
  puts "   Log: #{log_file}"
  puts "\n💡 Alternative backup options:"
  puts "   1. Use Azure Portal backup/export feature"
  puts "   2. Create a point-in-time restore"
  puts "   3. Use Azure Database Migration Service"
end 