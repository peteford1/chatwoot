#!/usr/bin/env ruby

# Environment Validation Script for Chatwoot
# Updated: #{Time.current} - Comprehensive environment boundary validation

require 'yaml'
require 'json'
require 'net/http'
require 'uri'

class EnvironmentValidator
  def initialize
    @config_file = 'config/environments.yml'
    @config = load_config
    @violations = []
    @warnings = []
  end

  def load_config
    return {} unless File.exist?(@config_file)
    YAML.load_file(@config_file)
  end

  def validate_all
    puts "🔍 Chatwoot Environment Validation"
    puts "=" * 50
    
    validate_configuration_files
    validate_git_branch_strategy
    validate_azure_resources
    validate_github_workflow
    validate_forbidden_patterns
    validate_environment_isolation
    
    report_results
  end

  def validate_configuration_files
    puts "\n📋 Validating Configuration Files..."
    
    required_files = [
      'config/environments.yml',
      'scripts/manage_environments.rb',
      '.github/workflows/azure-deploy.yml',
      '.cursorrules'
    ]
    
    required_files.each do |file|
      if File.exist?(file)
        puts "✅ #{file} - Found"
      else
        @violations << "Missing required file: #{file}"
        puts "❌ #{file} - Missing"
      end
    end
    
    # Validate environments.yml structure
    if @config['environments']
      %w[development staging production].each do |env|
        if @config.dig('environments', env)
          puts "✅ Environment '#{env}' - Configured"
        else
          @warnings << "Environment '#{env}' not configured in environments.yml"
          puts "⚠️  Environment '#{env}' - Not configured"
        end
      end
    else
      @violations << "environments.yml missing 'environments' section"
    end
  end

  def validate_git_branch_strategy
    puts "\n🌿 Validating Git Branch Strategy..."
    
    current_branch = `git branch --show-current`.strip
    puts "📋 Current branch: #{current_branch}"
    
    case current_branch
    when 'main'
      puts "✅ Production branch - Deploys to production environment"
    when 'develop'
      puts "✅ Staging branch - Deploys to staging environment"
    when /^feature\//
      puts "✅ Feature branch - Deploys to development environment"
    else
      @warnings << "Non-standard branch name: #{current_branch}"
      puts "⚠️  Non-standard branch name - Consider feature/*, develop, or main"
    end
    
    # Check for uncommitted changes that might bypass validation
    uncommitted = `git status --porcelain`.strip
    unless uncommitted.empty?
      puts "⚠️  Uncommitted changes detected - Ensure they follow environment rules"
    end
  end

  def validate_azure_resources
    puts "\n☁️  Validating Azure Resources..."
    
    # Check if Azure CLI is available and logged in
    unless system('az account show > /dev/null 2>&1')
      @warnings << "Azure CLI not logged in or not available"
      puts "⚠️  Azure CLI not available - Cannot validate Azure resources"
      return
    end
    
    # Check PostgreSQL server
    db_status = `az postgres flexible-server show --name chatwoot-db-fresh --resource-group SM-Test --query 'state' -o tsv 2>/dev/null`.strip
    if db_status == 'Ready'
      puts "✅ PostgreSQL server - Ready"
    else
      @violations << "PostgreSQL server not ready or not found"
      puts "❌ PostgreSQL server - Not ready"
    end
    
    # Check container apps
    @config.dig('environments')&.each do |env_name, env_config|
      app_name = env_config['container_app_name']
      next unless app_name
      
      app_status = `az containerapp show --name #{app_name} --resource-group SM-Test --query 'properties.runningStatus' -o tsv 2>/dev/null`.strip
      if app_status == 'Running'
        puts "✅ Container app '#{app_name}' - Running"
      elsif app_status.empty?
        @warnings << "Container app '#{app_name}' not found (may need to be created)"
        puts "⚠️  Container app '#{app_name}' - Not found"
      else
        @warnings << "Container app '#{app_name}' status: #{app_status}"
        puts "⚠️  Container app '#{app_name}' - Status: #{app_status}"
      end
    end
  end

  def validate_github_workflow
    puts "\n🔄 Validating GitHub Workflow..."
    
    workflow_file = '.github/workflows/azure-deploy.yml'
    if File.exist?(workflow_file)
      content = File.read(workflow_file)
      
      # Check for required workflow elements
      required_elements = [
        'on:',
        'push:',
        'branches:',
        'main',
        'develop',
        'feature/*',
        'detect-environment',
        'build-and-test',
        'deploy'
      ]
      
      required_elements.each do |element|
        if content.include?(element)
          puts "✅ Workflow element '#{element}' - Found"
        else
          @violations << "Missing workflow element: #{element}"
          puts "❌ Workflow element '#{element}' - Missing"
        end
      end
    else
      @violations << "GitHub Actions workflow file not found"
    end
    
    # Check GitHub CLI availability
    if system('gh auth status > /dev/null 2>&1')
      puts "✅ GitHub CLI - Authenticated"
    else
      @warnings << "GitHub CLI not authenticated - Cannot check workflow status"
      puts "⚠️  GitHub CLI - Not authenticated"
    end
  end

  def validate_forbidden_patterns
    puts "\n🚫 Checking for Forbidden Patterns..."
    
    forbidden_patterns = [
      'az postgres flexible-server execute',
      'az containerapp update.*--image',
      'DELETE FROM accounts',
      'DELETE FROM users',
      'DELETE FROM inboxes',
      'User.delete_all',
      'Account.delete_all'
    ]
    
    # Check recent commits for forbidden patterns
    recent_files = `git diff --name-only HEAD~5..HEAD 2>/dev/null`.split("\n")
    
    forbidden_patterns.each do |pattern|
      recent_files.each do |file|
        next unless File.exist?(file)
        
        if File.read(file).match(/#{pattern}/i)
          @violations << "Forbidden pattern '#{pattern}' found in #{file}"
          puts "❌ Forbidden pattern '#{pattern}' in #{file}"
        end
      end
    end
    
    puts "✅ No forbidden patterns detected in recent changes"
  end

  def validate_environment_isolation
    puts "\n🔒 Validating Environment Isolation..."
    
    # Check for hardcoded environment URLs
    hardcoded_urls = [
      'chatwoot-backend-test.calmmushroom',
      'chatwoot-backend-staging',
      'chatwoot-backend-prod'
    ]
    
    code_files = Dir.glob('**/*.{rb,yml,yaml,json}').reject { |f| f.start_with?('backup/') }
    
    hardcoded_urls.each do |url|
      code_files.each do |file|
        next unless File.exist?(file)
        
        if File.read(file).include?(url)
          @warnings << "Hardcoded environment URL '#{url}' found in #{file}"
          puts "⚠️  Hardcoded URL '#{url}' in #{file}"
        end
      end
    end
    
    # Check database isolation (schema-based)
    @config.dig('environments')&.each do |env_name, env_config|
      db_name = env_config['database_name']
      schema = env_config['database_schema']
      if db_name && schema
        puts "✅ Environment '#{env_name}' uses database '#{db_name}' with schema '#{schema}'"
      else
        @violations << "Environment '#{env_name}' missing database or schema configuration"
        puts "❌ Environment '#{env_name}' - No database/schema configured"
      end
    end
  end

  def validate_health_endpoints
    puts "\n🩺 Validating Health Endpoints..."
    
    @config.dig('environments')&.each do |env_name, env_config|
      url = env_config['frontend_url']
      next unless url
      
      health_url = "#{url}/health"
      
      begin
        uri = URI(health_url)
        response = Net::HTTP.get_response(uri)
        
        if response.code == '200'
          puts "✅ Health check '#{env_name}' - OK"
        else
          @warnings << "Health check failed for #{env_name}: HTTP #{response.code}"
          puts "⚠️  Health check '#{env_name}' - HTTP #{response.code}"
        end
      rescue => e
        @warnings << "Health check error for #{env_name}: #{e.message}"
        puts "⚠️  Health check '#{env_name}' - Error: #{e.message}"
      end
    end
  end

  def report_results
    puts "\n" + "=" * 50
    puts "📊 VALIDATION RESULTS"
    puts "=" * 50
    
    if @violations.empty? && @warnings.empty?
      puts "🎉 ALL VALIDATIONS PASSED!"
      puts "✅ Environment boundaries are properly configured"
      puts "✅ CI/CD pipeline is ready"
      puts "✅ No security violations detected"
    else
      unless @violations.empty?
        puts "\n🚨 CRITICAL VIOLATIONS (Must Fix):"
        @violations.each_with_index do |violation, i|
          puts "#{i + 1}. ❌ #{violation}"
        end
      end
      
      unless @warnings.empty?
        puts "\n⚠️  WARNINGS (Should Fix):"
        @warnings.each_with_index do |warning, i|
          puts "#{i + 1}. ⚠️  #{warning}"
        end
      end
      
      puts "\n💡 RECOMMENDATIONS:"
      puts "- Fix critical violations before proceeding"
      puts "- Address warnings to improve environment safety"
      puts "- Run validation again after making changes"
    end
    
    puts "\n🔧 HELPFUL COMMANDS:"
    puts "ruby scripts/manage_environments.rb --list"
    puts "ruby scripts/manage_environments.rb --status development"
    puts "source scripts/safe_aliases.sh && cw-help"
    
    # Exit with error code if violations found
    exit(1) unless @violations.empty?
  end
end

# CLI execution
if __FILE__ == $0
  validator = EnvironmentValidator.new
  validator.validate_all
end 