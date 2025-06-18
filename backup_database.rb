#!/usr/bin/env ruby

require 'fileutils'
require 'time'
require 'json'

puts "💾 Starting Database Backup Process..."

# Create timestamp for backup
timestamp = Time.now.to_i
backup_date = Time.now.strftime("%Y%m%d_%H%M%S")

# Backup directory structure
backup_root = "backup"
backup_dir = "#{backup_root}/database_backup_#{timestamp}"

puts "\n📁 Creating backup directory: #{backup_dir}"
FileUtils.mkdir_p(backup_dir)

# Database configuration
db_config = {
  host: 'chatwoot-db-fresh.postgres.database.azure.com',
  port: 5432,
  database: 'chatwoot_production',
  username: 'chatwoot_prod',
  password: 'chatwoot_prod'
}

puts "\n🔗 Database Connection Details:"
puts "   Host: #{db_config[:host]}"
puts "   Database: #{db_config[:database]}"
puts "   User: #{db_config[:username]}"

# Create backup info file
backup_info = {
  timestamp: timestamp,
  date: backup_date,
  database: db_config[:database],
  host: db_config[:host],
  backup_type: "full_database_dump",
  created_by: "database_backup_script",
  reason: "Manual backup requested by user"
}

puts "\n📝 Creating backup metadata..."
File.write("#{backup_dir}/backup_info.json", JSON.pretty_generate(backup_info))

# Create the pg_dump command
dump_file = "#{backup_dir}/chatwoot_production_#{backup_date}.sql"
log_file = "#{backup_dir}/backup_log_#{backup_date}.txt"

# Set PGPASSWORD environment variable for authentication
ENV['PGPASSWORD'] = db_config[:password]

pg_dump_cmd = [
  "pg_dump",
  "--host=#{db_config[:host]}",
  "--port=#{db_config[:port]}",
  "--username=#{db_config[:username]}",
  "--dbname=#{db_config[:database]}",
  "--verbose",
  "--clean",
  "--if-exists",
  "--create",
  "--format=plain",
  "--file=#{dump_file}",
  "2>&1 | tee #{log_file}"
].join(" ")

puts "\n🚀 Starting database dump..."
puts "   Command: pg_dump --host=#{db_config[:host]} --dbname=#{db_config[:database]}"
puts "   Output file: #{dump_file}"
puts "   Log file: #{log_file}"

# Execute the backup
puts "\n⏳ This may take several minutes for large databases..."
start_time = Time.now

success = system(pg_dump_cmd)

end_time = Time.now
duration = (end_time - start_time).round(2)

if success
  puts "\n✅ Database backup completed successfully!"
  puts "   Duration: #{duration} seconds"
  
  # Check file size
  if File.exist?(dump_file)
    file_size = File.size(dump_file)
    file_size_mb = (file_size / 1024.0 / 1024.0).round(2)
    puts "   Backup size: #{file_size_mb} MB"
    
    # Update backup info with results
    backup_info[:status] = "success"
    backup_info[:duration_seconds] = duration
    backup_info[:file_size_bytes] = file_size
    backup_info[:file_size_mb] = file_size_mb
  else
    puts "   ⚠️  Warning: Backup file not found after dump"
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
# Database Backup Summary
Date: #{Time.now}
Backup Directory: #{backup_dir}
Database: #{db_config[:database]}
Host: #{db_config[:host]}
Status: #{backup_info[:status]}
Duration: #{duration} seconds
#{backup_info[:file_size_mb] ? "Size: #{backup_info[:file_size_mb]} MB" : ""}

## Files Created:
- #{dump_file}
- #{log_file}
- #{backup_dir}/backup_info.json
- #{backup_dir}/backup_summary.md

## Restore Command:
psql --host=#{db_config[:host]} --port=#{db_config[:port]} --username=#{db_config[:username]} --dbname=#{db_config[:database]} < #{dump_file}
SUMMARY

File.write("#{backup_dir}/backup_summary.md", summary)

puts "\n📁 Backup files created in: #{backup_dir}"
puts "   - SQL dump: #{File.basename(dump_file)}"
puts "   - Log file: #{File.basename(log_file)}"
puts "   - Metadata: backup_info.json"
puts "   - Summary: backup_summary.md"

# Clean up environment variable
ENV.delete('PGPASSWORD')

puts "\n✨ Database backup process completed!"

if success
  puts "\n🎉 SUCCESS: Database backup is ready for use"
  puts "   Location: #{dump_file}"
else
  puts "\n⚠️  FAILED: Check log file for error details"
  puts "   Log: #{log_file}"
end 