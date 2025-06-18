#!/usr/bin/env ruby

require 'fileutils'
require 'time'

puts '🔍 ANALYZING ROOT DIRECTORY SCRIPTS...'

# Get all files in root (excluding directories and standard files)
all_files = Dir.glob('*').select { |f| File.file?(f) }

# Exclude essential files that should never be moved
essential_files = %w[
  Gemfile Gemfile.lock package.json pnpm-lock.yaml
  Rakefile Capfile config.ru
  README.md LICENSE SECURITY.md
  docker-compose.yaml docker-compose.production.yaml docker-compose.test.yaml
  Procfile Procfile.dev Procfile.test
  Dockerfile Dockerfile.azure
  .gitignore .ruby-version .nvmrc
  krakend.json krakend-simple.json
]

# Get files to analyze (exclude essential files and directories)
files_to_analyze = all_files.reject { |f| essential_files.include?(f) || File.directory?(f) }

puts "📊 Found #{files_to_analyze.length} files to analyze"

# Categorize files
categories = {
  essential: [],
  active_dev: [],
  testing_debug: [],
  setup_scripts: [],
  documentation: [],
  backup_old: []
}

files_to_analyze.each do |file|
  case file
  # Essential operational files
  when /^(deploy_.*fixed|deploy_.*final|setup_ssl.*fixed|ssl_.*fixed)/
    categories[:essential] << file
  when 'krakend-simple.json'
    categories[:essential] << file
    
  # Active development (recent token/admin scripts)
  when /^(create_.*platform.*token|get_.*platform.*token|create_.*admin|fix_platform)/
    categories[:active_dev] << file
    
  # Testing and debug scripts
  when /^(test_|debug_|verify_|check_|simple_.*test)/
    categories[:testing_debug] << file
    
  # Setup scripts (one-time use)
  when /^(setup_|install_|configure_|enable_)/
    categories[:setup_scripts] << file
    
  # Documentation files
  when /\.(md|txt)$/
    categories[:documentation] << file
    
  # Backup and old files
  when /\.(bak|backup|temp)$/, /backup-\d+/, /\.old$/, /old_config/
    categories[:backup_old] << file
    
  # KrakenD configs (keep only simple, archive others)
  when /^krakend.*\.json$/
    if file == 'krakend-simple.json'
      categories[:essential] << file
    else
      categories[:backup_old] << file
    end
    
  # Default categorization
  else
    if file.match?(/account|user|admin|token/) && !file.match?(/test|debug/)
      categories[:active_dev] << file
    elsif file.match?(/test|debug|check|verify/)
      categories[:testing_debug] << file
    else
      categories[:backup_old] << file
    end
  end
end

# Display analysis
puts "\n📋 CATEGORIZATION RESULTS:"
puts "=" * 50

categories.each do |category, files|
  next if files.empty?
  
  puts "\n#{category.to_s.upcase.gsub('_', ' ')} (#{files.length} files):"
  files.sort.each { |f| puts "  • #{f}" }
end

# Calculate totals
keep_count = categories[:essential].length + categories[:active_dev].length
archive_count = categories[:testing_debug].length + categories[:setup_scripts].length + 
                categories[:documentation].length + categories[:backup_old].length

puts "\n" + "=" * 50
puts "📊 SUMMARY:"
puts "✅ KEEP IN ROOT: #{keep_count} files"
puts "📦 ARCHIVE: #{archive_count} files"

if archive_count > 0
  puts "\n🤖 CREATING ARCHIVE..."
  
  # Create archive directory with timestamp
  archive_date = Time.now.strftime('%Y%m%d_%H%M%S')
  archive_dir = "archive_#{archive_date}"
  
  # Create archive structure
  FileUtils.mkdir_p("#{archive_dir}/testing_debug")
  FileUtils.mkdir_p("#{archive_dir}/setup_scripts")
  FileUtils.mkdir_p("#{archive_dir}/documentation")
  FileUtils.mkdir_p("#{archive_dir}/backup_old")
  
  moved_count = 0
  
  # Move files to archive
  categories[:testing_debug].each do |file|
    if File.exist?(file)
      FileUtils.mv(file, "#{archive_dir}/testing_debug/")
      puts "  📦 #{file} → testing_debug/"
      moved_count += 1
    end
  end
  
  categories[:setup_scripts].each do |file|
    if File.exist?(file)
      FileUtils.mv(file, "#{archive_dir}/setup_scripts/")
      puts "  📦 #{file} → setup_scripts/"
      moved_count += 1
    end
  end
  
  categories[:documentation].each do |file|
    if File.exist?(file)
      FileUtils.mv(file, "#{archive_dir}/documentation/")
      puts "  📦 #{file} → documentation/"
      moved_count += 1
    end
  end
  
  categories[:backup_old].each do |file|
    if File.exist?(file)
      FileUtils.mv(file, "#{archive_dir}/backup_old/")
      puts "  📦 #{file} → backup_old/"
      moved_count += 1
    end
  end
  
  # Create summary file
  summary_content = <<~SUMMARY
    # Archive Summary - #{Time.now.strftime("%Y-%m-%d %H:%M:%S")}
    
    ## Total Files Archived: #{moved_count}
    
    ### Testing/Debug (#{categories[:testing_debug].length} files)
    #{categories[:testing_debug].sort.map { |f| "- #{f}" }.join("\n")}
    
    ### Setup Scripts (#{categories[:setup_scripts].length} files)
    #{categories[:setup_scripts].sort.map { |f| "- #{f}" }.join("\n")}
    
    ### Documentation (#{categories[:documentation].length} files)
    #{categories[:documentation].sort.map { |f| "- #{f}" }.join("\n")}
    
    ### Backup/Old (#{categories[:backup_old].length} files)
    #{categories[:backup_old].sort.map { |f| "- #{f}" }.join("\n")}
    
    ## Files Kept in Root: #{keep_count}
    
    ### Essential
    #{categories[:essential].sort.map { |f| "- #{f}" }.join("\n")}
    
    ### Active Development
    #{categories[:active_dev].sort.map { |f| "- #{f}" }.join("\n")}
  SUMMARY
  
  File.write("#{archive_dir}/ARCHIVE_SUMMARY.md", summary_content)
  
  puts "\n✅ ARCHIVE COMPLETE!"
  puts "📁 Archive created: #{archive_dir}/"
  puts "📄 Summary: #{archive_dir}/ARCHIVE_SUMMARY.md"
  puts "🎯 #{moved_count} files archived, #{keep_count} files kept in root"
  
else
  puts "\n✅ No files need archiving!"
end

puts "\n🏁 DONE!" 