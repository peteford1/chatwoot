#!/usr/bin/env ruby

# Shared Database Setup Script for Chatwoot
# Updated: #{Time.current} - Creates shared database with environment-specific schemas

require 'yaml'

class SharedDatabaseSetup
  def initialize
    @config_file = 'config/environments.yml'
    @config = load_config
    @server_name = 'chatwoot-db-fresh'
    @resource_group = 'SM-Test'
    @shared_db_name = 'chatwoot_shared'
  end

  def load_config
    return {} unless File.exist?(@config_file)
    YAML.load_file(@config_file)
  end

  def setup_database
    puts "🗄️  Setting up Shared Database with Schema Isolation"
    puts "=" * 60
    
    create_shared_database
    generate_schema_commands
    show_connection_examples
    update_existing_database
  end

  def create_shared_database
    puts "\n1️⃣  Creating Shared Database"
    puts "-" * 30
    
    puts "📋 Creating database '#{@shared_db_name}' on server '#{@server_name}'"
    
    cmd = [
      "az postgres flexible-server db create",
      "--server-name #{@server_name}",
      "--resource-group #{@resource_group}",
      "--database-name #{@shared_db_name}"
    ].join(" \\\n  ")
    
    puts "\n🔧 Command to run:"
    puts cmd
    puts "\n💡 This creates a new database that all environments will share"
  end

  def generate_schema_commands
    puts "\n2️⃣  Schema Creation Commands"
    puts "-" * 30
    
    puts "📋 Connect to the shared database and run these commands:"
    puts "\n# Connect to database:"
    puts "psql postgresql://\${DB_USERNAME}:\${DB_PASSWORD}@#{@server_name}.postgres.database.azure.com:5432/#{@shared_db_name}"
    puts ""
    
    @config['environments']&.each do |env_name, config|
      schema = config['database_schema']
      puts "-- #{env_name.upcase} Environment Schema"
      puts "CREATE SCHEMA IF NOT EXISTS #{schema};"
      puts "COMMENT ON SCHEMA #{schema} IS 'Chatwoot #{env_name} environment data';"
      puts ""
    end
    
    puts "-- Grant permissions (replace 'chatwoot_user' with your actual username)"
    @config['environments']&.each do |env_name, config|
      schema = config['database_schema']
      puts "GRANT ALL PRIVILEGES ON SCHEMA #{schema} TO chatwoot_user;"
      puts "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA #{schema} TO chatwoot_user;"
      puts "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA #{schema} TO chatwoot_user;"
      puts "ALTER DEFAULT PRIVILEGES IN SCHEMA #{schema} GRANT ALL ON TABLES TO chatwoot_user;"
      puts "ALTER DEFAULT PRIVILEGES IN SCHEMA #{schema} GRANT ALL ON SEQUENCES TO chatwoot_user;"
      puts ""
    end
    
    puts "-- Verify schemas were created:"
    puts "\\dn"
    puts ""
    puts "-- Test schema switching:"
    puts "SET search_path TO development;"
    puts "SHOW search_path;"
  end

  def show_connection_examples
    puts "\n3️⃣  Connection String Examples"
    puts "-" * 30
    
    @config['environments']&.each do |env_name, config|
      schema = config['database_schema']
      puts "\n📋 #{env_name.upcase} Environment:"
      puts "DATABASE_URL=postgresql://username:password@#{@server_name}.postgres.database.azure.com:5432/#{@shared_db_name}?options=-csearch_path%3D#{schema}"
    end
    
    puts "\n💡 The ?options=-csearch_path%3D{schema} parameter ensures each environment only sees its own data"
  end

  def update_existing_database
    puts "\n4️⃣  Migrating from Existing Databases (Optional)"
    puts "-" * 30
    
    puts "If you have existing data in separate databases, you can migrate it:"
    puts ""
    
    existing_databases = ['chatwoot', 'chatwoot_staging', 'chatwoot_production']
    
    existing_databases.each_with_index do |old_db, index|
      env_name = ['development', 'staging', 'production'][index]
      schema = @config.dig('environments', env_name, 'database_schema')
      
      puts "# Migrate #{old_db} → #{@shared_db_name}.#{schema}"
      puts "pg_dump postgresql://username:password@#{@server_name}.postgres.database.azure.com:5432/#{old_db} | \\"
      puts "  sed 's/public\\./#{schema}\\./g' | \\"
      puts "  psql postgresql://username:password@#{@server_name}.postgres.database.azure.com:5432/#{@shared_db_name}"
      puts ""
    end
    
    puts "⚠️  Test migrations thoroughly before dropping old databases!"
  end

  def verify_setup
    puts "\n5️⃣  Verification Steps"
    puts "-" * 30
    
    puts "After setup, verify everything works:"
    puts ""
    puts "1. Test environment management:"
    puts "   ruby scripts/manage_environments_schema.rb --list"
    puts ""
    puts "2. Check each environment can connect:"
    @config['environments']&.each do |env_name, config|
      puts "   ruby scripts/manage_environments_schema.rb --status #{env_name}"
    end
    puts ""
    puts "3. Test Rails migrations in each schema:"
    puts "   # Set environment and run migrations"
    puts "   RAILS_ENV=development bundle exec rails db:migrate"
    puts "   RAILS_ENV=staging bundle exec rails db:migrate"
    puts "   RAILS_ENV=production bundle exec rails db:migrate"
    puts ""
    puts "4. Verify data isolation:"
    puts "   # Each environment should only see its own data"
    puts "   # Create test data in development, verify staging doesn't see it"
  end

  def show_cost_benefits
    puts "\n💰 Cost Benefits of Shared Database"
    puts "-" * 30
    
    puts "✅ Single PostgreSQL server instead of 3 separate ones"
    puts "✅ Reduced backup and maintenance overhead"
    puts "✅ Simplified connection management"
    puts "✅ Better resource utilization"
    puts "✅ Same level of data isolation as separate databases"
    puts ""
    puts "💡 Estimated savings: 60-70% on database costs"
  end
end

# CLI execution
if __FILE__ == $0
  setup = SharedDatabaseSetup.new
  
  puts "🚀 Chatwoot Shared Database Setup"
  puts "=" * 50
  
  setup.setup_database
  setup.verify_setup
  setup.show_cost_benefits
  
  puts "\n🎉 Setup guide complete!"
  puts "📋 Next steps:"
  puts "1. Run the Azure CLI command to create the database"
  puts "2. Connect to PostgreSQL and run the schema creation commands"
  puts "3. Update your GitHub secrets with the new DATABASE_URL format"
  puts "4. Test each environment"
end 