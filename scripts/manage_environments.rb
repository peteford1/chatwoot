#!/usr/bin/env ruby

# Environment Management Script for Chatwoot
# Updated: #{Time.current} - Added schema-based database isolation

require 'yaml'
require 'json'
require 'optparse'

class EnvironmentManager
  def initialize
    @config_file = 'config/environments.yml'
    @config = load_config
  end

  def load_config
    return {} unless File.exist?(@config_file)
    YAML.load_file(@config_file)
  end

  def list_environments
    puts "🌍 Available Environments (Schema-based Isolation):"
    puts "=" * 60
    
    @config['environments']&.each do |env_name, config|
      puts "\n📋 #{env_name.upcase}"
      puts "   Database: #{config['database_name']}"
      puts "   Schema: #{config['database_schema']}"
      puts "   Container App: #{config['container_app_name']}"
      puts "   Frontend URL: #{config['frontend_url']}"
      puts "   Rails Env: #{config['rails_env']}"
      puts "   Force SSL: #{config['force_ssl']}"
      puts "   Sidekiq Concurrency: #{config['sidekiq_concurrency']}"
    end
    
    puts "\n💡 Schema Benefits:"
    puts "   - Shared database reduces costs"
    puts "   - Complete data isolation between environments"
    puts "   - Easy backup and restore operations"
    puts "   - Simplified connection management"
  end

  def show_environment(env_name)
    env_config = @config.dig('environments', env_name)
    
    unless env_config
      puts "❌ Environment '#{env_name}' not found!"
      return
    end

    puts "🔍 Environment: #{env_name.upcase}"
    puts "=" * 50
    
    env_config.each do |key, value|
      puts "#{key.ljust(20)}: #{value}"
    end

    # Show Azure resources
    puts "\n🔧 Azure Resources:"
    @config['azure']&.each do |key, value|
      puts "#{key.ljust(20)}: #{value}"
    end

    # Show feature flags
    features = @config.dig('features', env_name)
    if features
      puts "\n🚩 Feature Flags:"
      features.each do |key, value|
        status = value ? "✅ Enabled" : "❌ Disabled"
        puts "#{key.ljust(20)}: #{status}"
      end
    end
    
    # Show database connection details
    puts "\n🗄️  Database Connection:"
    db_name = env_config['database_name']
    schema = env_config['database_schema']
    puts "Full Connection: postgresql://username:password@host:5432/#{db_name}?options=-csearch_path%3D#{schema}"
  end

  def generate_env_vars(env_name)
    env_config = @config.dig('environments', env_name)
    
    unless env_config
      puts "❌ Environment '#{env_name}' not found!"
      return
    end

    puts "📝 Environment Variables for #{env_name.upcase} (Schema: #{env_config['database_schema']}):"
    puts "=" * 70
    
    # Core Rails variables
    puts "export RAILS_ENV=#{env_config['rails_env']}"
    puts "export FRONTEND_URL=#{env_config['frontend_url']}"
    puts "export FORCE_SSL=#{env_config['force_ssl']}"
    puts "export RAILS_LOG_TO_STDOUT=true"
    puts "export RAILS_SERVE_STATIC_FILES=true"
    
    # Sidekiq
    puts "export SIDEKIQ_CONCURRENCY=#{env_config['sidekiq_concurrency']}"
    
    # Database with schema (placeholder - actual values from secrets)
    db_name = env_config['database_name']
    schema = env_config['database_schema']
    puts "export DATABASE_URL=postgresql://\${DB_USERNAME}:\${DB_PASSWORD}@\${DB_HOST}:5432/#{db_name}?options=-csearch_path%3D#{schema}"
    
    # Schema-specific variables
    puts "export DATABASE_SCHEMA=#{schema}"
    puts "export SHARED_DATABASE_NAME=#{db_name}"
    
    # Redis (placeholder - actual value from secrets)
    puts "export REDIS_URL=\${REDIS_URL}"
    
    # Secret key (placeholder - actual value from secrets)
    puts "export SECRET_KEY_BASE=\${SECRET_KEY_BASE}"

    # Feature flags
    features = @config.dig('features', env_name)
    if features
      puts "\n# Feature Flags"
      features.each do |key, value|
        puts "export #{key.upcase}=#{value}"
      end
    end
    
    puts "\n# Schema Management Commands"
    puts "# Create schema: CREATE SCHEMA IF NOT EXISTS #{schema};"
    puts "# Set search path: SET search_path TO #{schema};"
    puts "# List schemas: \\dn"
  end

  def create_container_app(env_name)
    env_config = @config.dig('environments', env_name)
    azure_config = @config['azure']
    
    unless env_config && azure_config
      puts "❌ Configuration not found!"
      return
    end

    app_name = env_config['container_app_name']
    
    puts "🚀 Creating Container App: #{app_name}"
    puts "=" * 50
    
    # Set replica configuration based on environment
    if env_name == 'production'
      min_replicas = 1
      max_replicas = 3
    else
      min_replicas = 0
      max_replicas = 1
    end
    
    # Generate az containerapp create command
    cmd = [
      "az containerapp create",
      "--name #{app_name}",
      "--resource-group #{azure_config['resource_group']}",
      "--environment #{azure_config['managed_environment']}",
      "--image #{azure_config['container_registry']}/chatwoot:latest",
      "--target-port 3000",
      "--ingress external",
      "--min-replicas #{min_replicas}",
      "--max-replicas #{max_replicas}",
      "--cpu 1.0",
      "--memory 2Gi"
    ].join(" \\\n  ")
    
    puts cmd
    puts "\n💡 Run this command to create the container app for #{env_name}"
    puts "📋 Schema '#{env_config['database_schema']}' will be used for data isolation"
  end

  def check_deployment_status(env_name)
    env_config = @config.dig('environments', env_name)
    azure_config = @config['azure']
    
    unless env_config && azure_config
      puts "❌ Configuration not found!"
      return
    end

    app_name = env_config['container_app_name']
    resource_group = azure_config['resource_group']
    
    puts "🔍 Checking deployment status for #{app_name}..."
    puts "📋 Schema: #{env_config['database_schema']}"
    
    # Check if container app exists
    system("az containerapp show --name #{app_name} --resource-group #{resource_group} > /dev/null 2>&1")
    
    if $?.success?
      puts "✅ Container app '#{app_name}' exists"
      
      # Get status
      status_cmd = "az containerapp show --name #{app_name} --resource-group #{resource_group} --query 'properties.runningStatus' -o tsv"
      status = `#{status_cmd}`.strip
      
      puts "📊 Status: #{status}"
      
      # Get URL
      url_cmd = "az containerapp show --name #{app_name} --resource-group #{resource_group} --query 'properties.configuration.ingress.fqdn' -o tsv"
      url = `#{url_cmd}`.strip
      
      puts "🌐 URL: https://#{url}" unless url.empty?
      puts "🗄️  Database: #{env_config['database_name']} (Schema: #{env_config['database_schema']})"
    else
      puts "❌ Container app '#{app_name}' does not exist"
      puts "💡 Run: ruby scripts/manage_environments.rb --create #{env_name}"
    end
  end

  def create_database_schemas
    puts "🗄️  Database Schema Setup Commands"
    puts "=" * 50
    
    puts "# Connect to shared database and create schemas:"
    puts "psql postgresql://username:password@chatwoot-db-fresh.postgres.database.azure.com:5432/chatwoot_shared"
    puts ""
    
    @config['environments']&.each do |env_name, config|
      schema = config['database_schema']
      puts "-- Create schema for #{env_name}"
      puts "CREATE SCHEMA IF NOT EXISTS #{schema};"
      puts "GRANT ALL PRIVILEGES ON SCHEMA #{schema} TO chatwoot_user;"
      puts "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA #{schema} TO chatwoot_user;"
      puts "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA #{schema} TO chatwoot_user;"
      puts ""
    end
    
    puts "# Verify schemas:"
    puts "\\dn"
    puts ""
    puts "# Switch to specific schema:"
    puts "SET search_path TO development;  -- or staging, production"
  end
end

# CLI Interface
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ruby scripts/manage_environments.rb [options]"

  opts.on("-l", "--list", "List all environments") do
    options[:action] = :list
  end

  opts.on("-s", "--show ENV", "Show specific environment details") do |env|
    options[:action] = :show
    options[:environment] = env
  end

  opts.on("-e", "--env-vars ENV", "Generate environment variables") do |env|
    options[:action] = :env_vars
    options[:environment] = env
  end

  opts.on("-c", "--create ENV", "Generate container app creation command") do |env|
    options[:action] = :create
    options[:environment] = env
  end

  opts.on("-t", "--status ENV", "Check deployment status") do |env|
    options[:action] = :status
    options[:environment] = env
  end

  opts.on("-d", "--setup-database", "Show database schema setup commands") do
    options[:action] = :setup_database
  end

  opts.on("-h", "--help", "Show this help") do
    puts opts
    exit
  end
end.parse!

manager = EnvironmentManager.new

case options[:action]
when :list
  manager.list_environments
when :show
  manager.show_environment(options[:environment])
when :env_vars
  manager.generate_env_vars(options[:environment])
when :create
  manager.create_container_app(options[:environment])
when :status
  manager.check_deployment_status(options[:environment])
when :setup_database
  manager.create_database_schemas
else
  puts "❌ No action specified. Use --help for usage information."
  puts ""
  puts "💡 Quick commands:"
  puts "   --list                    List all environments"
  puts "   --setup-database          Show schema setup commands"
  puts "   --status development      Check development status"
end 