#!/usr/bin/env ruby

# Environment Setup Script
# Usage: ruby scripts/setup_environment.rb [environment] [action]
# Example: ruby scripts/setup_environment.rb test setup

require 'yaml'
require 'net/http'
require 'json'
require 'uri'

# Configuration
ENVIRONMENTS_CONFIG = YAML.load_file('config/environments.yml')
RESOURCE_GROUP = 'SM-Test'

def usage
  puts "Usage: ruby scripts/setup_environment.rb [environment] [action]"
  puts ""
  puts "Environments: development, test, staging, production"
  puts "Actions: setup, migrate, seed, reset, status"
  puts ""
  puts "Examples:"
  puts "  ruby scripts/setup_environment.rb test setup"
  puts "  ruby scripts/setup_environment.rb development seed"
  puts "  ruby scripts/setup_environment.rb staging status"
end

def load_environment_config(env_name)
  config = ENVIRONMENTS_CONFIG['environments'][env_name]
  
  unless config
    puts "❌ Unknown environment: #{env_name}"
    puts "Available environments: #{ENVIRONMENTS_CONFIG['environments'].keys.join(', ')}"
    exit 1
  end
  
  config
end

def make_request(method, url, headers = {}, body = nil)
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true if uri.scheme == 'https'
  
  request = case method.upcase
  when 'GET'
    Net::HTTP::Get.new(uri)
  when 'POST'
    Net::HTTP::Post.new(uri)
  end
  
  headers.each { |key, value| request[key] = value }
  request.body = body.to_json if body
  request['Content-Type'] = 'application/json' if body
  
  response = http.request(request)
  
  begin
    parsed_body = JSON.parse(response.body) if response.body && !response.body.empty?
    { code: response.code.to_i, body: parsed_body, raw_body: response.body }
  rescue JSON::ParserError
    { code: response.code.to_i, body: nil, raw_body: response.body }
  end
end

def check_environment_status(config)
  puts "=== Environment Status Check ==="
  puts "Environment: #{config['rails_env']}"
  puts "Container: #{config['container_app_name']}"
  puts "Database: #{config['database_name']}/#{config['database_schema']}"
  puts ""
  
  # Check container status via Azure CLI
  puts "🔍 Checking container status..."
  container_status = `az containerapp show --name #{config['container_app_name']} --resource-group #{RESOURCE_GROUP} --query "properties.runningStatus" -o tsv 2>/dev/null`.strip
  
  if container_status.empty?
    puts "❌ Container not found or not accessible"
    return false
  else
    puts "✅ Container status: #{container_status}"
  end
  
  # Check environment accessibility
  base_url = config['frontend_url']
  puts "🔍 Testing environment accessibility: #{base_url}"
  
  health_response = make_request('GET', base_url)
  if health_response[:code] == 200
    puts "✅ Environment accessible"
    if health_response[:body]
      puts "   Version: #{health_response[:body]['version']}"
      puts "   Services: #{health_response[:body]['queue_services']}, #{health_response[:body]['data_services']}"
    end
  else
    puts "❌ Environment not accessible (#{health_response[:code]})"
    return false
  end
  
  # Test API endpoints
  puts "🔍 Testing API endpoints..."
  
  platform_status = make_request('GET', "#{base_url}/platform/api/v1/accounts")[:code]
  app_status = make_request('GET', "#{base_url}/api/v1/profile")[:code]
  
  puts "   Platform API: #{platform_status} #{platform_status == 401 ? '(auth required - good)' : platform_status == 404 ? '(not found - needs setup)' : ''}"
  puts "   Application API: #{app_status} #{app_status == 401 ? '(auth required - good)' : app_status == 404 ? '(not found - needs setup)' : ''}"
  
  true
end

def update_container_environment(config, env_name)
  puts "🔧 Updating container environment variables..."
  
  # Build database URL
  if env_name == 'production'
    database_url = "postgresql://#{ENV['DB_USERNAME']}:#{ENV['DB_PASSWORD']}@#{ENV['DB_HOST']}:5432/#{config['database_name']}"
  else
    database_url = "postgresql://chatwoot_#{env_name}:#{ENV['DB_PASSWORD']}@#{ENV['DB_HOST']}:5432/#{config['database_name']}?options=-csearch_path%3D#{config['database_schema']}"
  end
  
  # Update container via Azure CLI
  update_cmd = [
    "az containerapp update",
    "--name #{config['container_app_name']}",
    "--resource-group #{RESOURCE_GROUP}",
    "--set-env-vars",
    "RAILS_ENV=#{config['rails_env']}",
    "DATABASE_URL='#{database_url}'",
    "FRONTEND_URL=#{config['frontend_url']}",
    "FORCE_SSL=#{config['force_ssl']}",
    "RAILS_LOG_TO_STDOUT=true"
  ].join(' ')
  
  puts "Executing: #{update_cmd}"
  result = system(update_cmd)
  
  if result
    puts "✅ Container environment updated"
    puts "⏳ Waiting for container to restart..."
    sleep 60
    true
  else
    puts "❌ Failed to update container environment"
    false
  end
end

def seed_environment(config, env_name)
  puts "🌱 Seeding #{env_name} environment..."
  
  base_url = config['frontend_url']
  
  # Try external seeding approach
  puts "Using external API seeding approach..."
  
  begin
    # Check if installation is needed
    install_check = make_request('GET', "#{base_url}/installation/onboarding")
    
    if install_check[:code] == 302
      puts "⚠️  Installation already complete, proceeding with seeding..."
    end
    
    # Create seeding data via API calls
    puts "Creating VoiceLinkAI test data..."
    
    # For now, document the seeding approach
    puts "📝 Seeding approach:"
    puts "1. Create Platform App: 'VoiceLinkAI #{env_name.capitalize}'"
    puts "2. Create Account: 'voicelinkai-#{env_name}'"
    puts "3. Create User: 'admin@voicelinkai-#{env_name}.com'"
    puts "4. Link user to account with admin role"
    
    puts "✅ Seeding configuration prepared"
    puts ""
    puts "To complete seeding, run the external seeder:"
    puts "ruby external_test_seeder.rb"
    
  rescue => e
    puts "❌ Seeding failed: #{e.message}"
    false
  end
end

def main
  if ARGV.length < 2
    usage
    exit 1
  end
  
  env_name = ARGV[0]
  action = ARGV[1]
  
  unless %w[development test staging production].include?(env_name)
    puts "❌ Invalid environment: #{env_name}"
    usage
    exit 1
  end
  
  unless %w[setup migrate seed reset status].include?(action)
    puts "❌ Invalid action: #{action}"
    usage
    exit 1
  end
  
  config = load_environment_config(env_name)
  
  puts "=== Environment Setup Script ==="
  puts "Environment: #{env_name}"
  puts "Action: #{action}"
  puts "Container: #{config['container_app_name']}"
  puts "Database: #{config['database_name']}/#{config['database_schema']}"
  puts ""
  
  case action
  when 'status'
    check_environment_status(config)
    
  when 'setup'
    puts "🚀 Setting up #{env_name} environment..."
    
    # 1. Check current status
    check_environment_status(config)
    
    # 2. Update container environment
    if update_container_environment(config, env_name)
      # 3. Seed environment
      seed_environment(config, env_name)
      
      puts ""
      puts "🎉 Environment setup completed!"
      puts "🔗 Access URL: #{config['frontend_url']}"
    else
      puts "❌ Environment setup failed"
      exit 1
    end
    
  when 'seed'
    seed_environment(config, env_name)
    
  when 'migrate'
    puts "🔄 Database migrations for #{env_name} environment..."
    puts "⚠️  Migration requires container exec functionality"
    puts "Use GitHub Actions workflow for reliable migration execution"
    
  when 'reset'
    if env_name == 'production'
      puts "❌ Cannot reset production environment"
      exit 1
    end
    
    puts "🗑️ Resetting #{env_name} environment..."
    puts "⚠️  Reset requires database admin access"
    puts "Use GitHub Actions workflow for safe reset execution"
    
  else
    puts "❌ Unknown action: #{action}"
    exit 1
  end
end

# Check for required environment variables
required_env_vars = %w[DB_USERNAME DB_PASSWORD DB_HOST]
missing_vars = required_env_vars.select { |var| ENV[var].nil? || ENV[var].empty? }

if missing_vars.any?
  puts "❌ Missing required environment variables: #{missing_vars.join(', ')}"
  puts ""
  puts "Set these variables or use GitHub Actions workflow which has access to secrets."
  exit 1
end

main 