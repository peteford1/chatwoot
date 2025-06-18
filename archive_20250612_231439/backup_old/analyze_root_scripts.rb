#!/usr/bin/env ruby

require 'fileutils'

# Get all Ruby and shell scripts in root
scripts = Dir.glob("*.{rb,sh,sql,lua,js,html,md,yaml,yml,json}").reject do |file|
  # Exclude standard files that should stay
  %w[
    Gemfile Gemfile.lock package.json pnpm-lock.yaml
    Rakefile Capfile config.ru
    README.md LICENSE SECURITY.md
    docker-compose.yaml docker-compose.production.yaml
    krakend.json
    Procfile Procfile.dev Procfile.test
    Dockerfile.azure
  ].include?(file)
end

# Categorize scripts
categories = {
  # Essential - Keep in root
  essential: [],
  
  # Active development - Keep for now
  active_dev: [],
  
  # Testing/Debug - Can archive
  testing_debug: [],
  
  # One-time setup - Can archive
  setup_scripts: [],
  
  # Documentation - Can archive
  documentation: [],
  
  # Backup/Old - Can archive
  backup_old: []
}

scripts.each do |script|
  case script
  # Essential operational scripts
  when /^(deploy_|setup_ssl|ssl_|dns_|cloudflare_)/
    if script.include?('fixed') || script.include?('final') || script.include?('working')
      categories[:essential] << script
    else
      categories[:backup_old] << script
    end
    
  # Current working configurations
  when 'krakend-simple.json', /krakend.*simple/, /azure.*deployment/
    categories[:essential] << script
    
  # Active development scripts
  when /^(create_|get_|list_|check_|update_|fix_)/
    if script.include?('platform') || script.include?('token') || script.include?('admin')
      categories[:active_dev] << script
    else
      categories[:testing_debug] << script
    end
    
  # Test scripts
  when /^test_/, /debug_/, /verify_/, /monitor_/
    categories[:testing_debug] << script
    
  # Setup scripts (one-time use)
  when /setup/, /install/, /configure/, /enable_/
    categories[:setup_scripts] << script
    
  # Documentation
  when /\.md$/, /GUIDE/, /SUMMARY/, /CHANGELOG/
    categories[:documentation] << script
    
  # Backup configurations
  when /\.bak$/, /backup/, /\.temp$/, /old_/
    categories[:backup_old] << script
    
  # HTML demos and examples
  when /\.html$/, /demo/, /example/
    categories[:testing_debug] << script
    
  else
    # Default categorization based on content patterns
    if script.match?(/account|user|admin|token/)
      categories[:active_dev] << script
    elsif script.match?(/test|debug|check/)
      categories[:testing_debug] << script
    else
      categories[:backup_old] << script
    end
  end
end

puts "📊 ROOT FOLDER SCRIPT ANALYSIS"
puts "=" * 50

categories.each do |category, files|
  next if files.empty?
  
  puts "\n#{category.to_s.upcase.gsub('_', ' ')} (#{files.length} files):"
  files.sort.each { |f| puts "  • #{f}" }
end

puts "\n" + "=" * 50
puts "RECOMMENDATIONS:"
puts "✅ KEEP IN ROOT (#{categories[:essential].length + categories[:active_dev].length} files)"
puts "📦 ARCHIVE (#{categories[:testing_debug].length + categories[:setup_scripts].length + categories[:documentation].length + categories[:backup_old].length} files)"

# Create archive structure
archive_date = Time.now.strftime("%Y%m%d")
archive_base = "archive_#{archive_date}"

puts "\n🗂️  PROPOSED ARCHIVE STRUCTURE:"
puts "#{archive_base}/"
puts "├── testing_debug/"
puts "├── setup_scripts/"  
puts "├── documentation/"
puts "└── backup_old/"

puts "\nWould you like me to create this archive structure? (y/n)" 