#!/bin/bash

echo "🔐 Creating Environment-Specific Database Users"
echo "================================================"

DB_SERVER="chatwoot-db-fresh"
RESOURCE_GROUP="SM-Test"

# Environment-specific database users
declare -A ENV_USERS=(
    ["development"]="chatwoot_dev:DevSecure2025!:chatwoot_shared:development"
    ["test"]="chatwoot_test:TestSecure2025!:chatwoot_shared:test"
    ["staging"]="chatwoot_staging:StagingSecure2025!:chatwoot_shared:staging"
    ["production"]="chatwoot_prod:ProdSecure2025!:chatwoot_production:public"
)

for env in "${!ENV_USERS[@]}"; do
    IFS=':' read -r username password database schema <<< "${ENV_USERS[$env]}"
    
    echo ""
    echo "🔧 Setting up $env environment..."
    echo "User: $username, Database: $database, Schema: $schema"
    
    # Create schema and user
    SQL_COMMANDS="
    -- Create database if it doesn't exist (for production)
    CREATE DATABASE IF NOT EXISTS $database;
    
    -- Connect to the database
    \\c $database;
    
    -- Create schema if it doesn't exist
    CREATE SCHEMA IF NOT EXISTS $schema;
    
    -- Create user if it doesn't exist
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$username') THEN
            CREATE USER $username WITH PASSWORD '$password';
        END IF;
    END
    \$\$;
    
    -- Grant schema permissions
    GRANT USAGE ON SCHEMA $schema TO $username;
    GRANT CREATE ON SCHEMA $schema TO $username;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA $schema TO $username;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA $schema TO $username;
    
    -- Set default privileges for future objects
    ALTER DEFAULT PRIVILEGES IN SCHEMA $schema GRANT ALL ON TABLES TO $username;
    ALTER DEFAULT PRIVILEGES IN SCHEMA $schema GRANT ALL ON SEQUENCES TO $username;
    
    -- Set default search path for the user
    ALTER USER $username SET search_path TO $schema;
    "
    
    echo "📋 Executing SQL commands for $env..."
    echo "$SQL_COMMANDS" > "/tmp/${env}_setup.sql"
    
    # Execute using Azure CLI
    az postgres flexible-server execute \
        --name $DB_SERVER \
        --resource-group $RESOURCE_GROUP \
        --admin-user chatwootuser \
        --admin-password "ChatwootSecure2025!" \
        --database-name $database \
        --file-path "/tmp/${env}_setup.sql" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "✅ $env user created successfully!"
    else
        echo "❌ Failed to create $env user"
        
        # Try individual commands for better error handling
        echo "🔄 Trying individual commands..."
        az postgres flexible-server execute \
            --name $DB_SERVER \
            --resource-group $RESOURCE_GROUP \
            --admin-user chatwootuser \
            --admin-password "ChatwootSecure2025!" \
            --database-name $database \
            --querytext "CREATE SCHEMA IF NOT EXISTS $schema;" || echo "Schema creation failed"
            
        az postgres flexible-server execute \
            --name $DB_SERVER \
            --resource-group $RESOURCE_GROUP \
            --admin-user chatwootuser \
            --admin-password "ChatwootSecure2025!" \
            --database-name $database \
            --querytext "CREATE USER $username WITH PASSWORD '$password';" || echo "User creation failed (may already exist)"
    fi
    
    # Clean up temp file
    rm -f "/tmp/${env}_setup.sql"
done

echo ""
echo "🎯 ENVIRONMENT DATABASE USERS SUMMARY:"
echo "======================================"

for env in "${!ENV_USERS[@]}"; do
    IFS=':' read -r username password database schema <<< "${ENV_USERS[$env]}"
    echo "$env:"
    echo "  User: $username"
    echo "  Password: $password"
    echo "  Database: $database"
    echo "  Schema: $schema"
    echo "  Connection: postgresql://$username:$password@chatwoot-db-fresh.postgres.database.azure.com:5432/$database?options=-csearch_path%3D$schema"
    echo ""
done

echo "🔐 SECURITY BENEFITS:"
echo "- Each environment has its own database user"
echo "- Users can only access their assigned schema"
echo "- Prevents accidental cross-environment data access"
echo "- Enables environment-specific permission auditing" 