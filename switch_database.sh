#!/bin/bash

# Chatwoot Database Configuration Switcher
# Usage: ./switch_database.sh [azure|local|test]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_usage() {
    echo "🔧 Chatwoot Database Configuration Switcher"
    echo ""
    echo "Usage: $0 [azure|local|test]"
    echo ""
    echo "Options:"
    echo "  azure  - Connect to Azure PostgreSQL production database"
    echo "  local  - Connect to local PostgreSQL development database"
    echo "  test   - Connect to local PostgreSQL test database"
    echo ""
    echo "Examples:"
    echo "  $0 azure    # Switch to Azure production database"
    echo "  $0 local    # Switch to local development database"
    echo ""
}

configure_azure() {
    echo "🚀 Configuring for Azure PostgreSQL Database..."
    
    # Source the Azure configuration
    source "$SCRIPT_DIR/azure_database_config.env"
    
    echo ""
    echo "✅ Azure Database Configuration Active"
    echo "   Host: $POSTGRES_HOST"
    echo "   Database: $POSTGRES_DATABASE"
    echo "   Environment: $RAILS_ENV"
    echo ""
    echo "💡 Next steps:"
    echo "   1. Test connection: rails runner \"puts ActiveRecord::Base.connection.current_database\""
    echo "   2. Run console: rails console"
    echo "   3. Run scripts: rails runner your_script.rb"
    echo ""
}

configure_local() {
    echo "🏠 Configuring for Local PostgreSQL Database..."
    
    # Unset Azure variables and set local ones
    unset POSTGRES_HOST POSTGRES_DATABASE POSTGRES_USERNAME POSTGRES_PASSWORD
    unset POSTGRES_SSLMODE RAILS_ENV
    
    export POSTGRES_HOST=localhost
    export POSTGRES_PORT=5432
    export POSTGRES_DATABASE=chatwoot_dev
    export POSTGRES_USERNAME=postgres
    export POSTGRES_PASSWORD=""
    export RAILS_ENV=development
    
    echo ""
    echo "✅ Local Database Configuration Active"
    echo "   Host: $POSTGRES_HOST"
    echo "   Database: $POSTGRES_DATABASE"
    echo "   Environment: $RAILS_ENV"
    echo ""
    echo "💡 Next steps:"
    echo "   1. Create database: rails db:create"
    echo "   2. Run migrations: rails db:migrate"
    echo "   3. Seed data: rails db:seed"
    echo ""
}

configure_test() {
    echo "🧪 Configuring for Test Database..."
    
    # Unset Azure variables and set test ones
    unset POSTGRES_HOST POSTGRES_DATABASE POSTGRES_USERNAME POSTGRES_PASSWORD
    unset POSTGRES_SSLMODE RAILS_ENV
    
    export POSTGRES_HOST=localhost
    export POSTGRES_PORT=5432
    export POSTGRES_DATABASE=chatwoot_test
    export POSTGRES_USERNAME=postgres
    export POSTGRES_PASSWORD=""
    export RAILS_ENV=test
    
    echo ""
    echo "✅ Test Database Configuration Active"
    echo "   Host: $POSTGRES_HOST"
    echo "   Database: $POSTGRES_DATABASE"
    echo "   Environment: $RAILS_ENV"
    echo ""
    echo "💡 Next steps:"
    echo "   1. Prepare test database: rails db:test:prepare"
    echo "   2. Run tests: rspec"
    echo ""
}

test_connection() {
    echo "🔍 Testing database connection..."
    
    if rails runner "puts 'Connected to: ' + ActiveRecord::Base.connection.current_database" 2>/dev/null; then
        echo "✅ Database connection successful!"
    else
        echo "❌ Database connection failed!"
        echo "   Check your database configuration and ensure the database server is running."
        return 1
    fi
}

# Main script logic
case "${1:-}" in
    azure)
        configure_azure
        ;;
    local)
        configure_local
        ;;
    test)
        configure_test
        ;;
    "")
        show_usage
        exit 1
        ;;
    *)
        echo "❌ Unknown option: $1"
        echo ""
        show_usage
        exit 1
        ;;
esac

# Test the connection
echo "🔍 Testing connection..."
if test_connection; then
    echo ""
    echo "🎉 Database configuration complete and tested!"
    echo ""
    echo "📋 Current Environment Variables:"
    echo "   POSTGRES_HOST=$POSTGRES_HOST"
    echo "   POSTGRES_DATABASE=$POSTGRES_DATABASE"
    echo "   POSTGRES_USERNAME=$POSTGRES_USERNAME"
    echo "   RAILS_ENV=$RAILS_ENV"
else
    echo ""
    echo "⚠️  Database configuration set but connection test failed."
    echo "   The environment variables are configured correctly."
    echo "   Please check database server availability and credentials."
fi 