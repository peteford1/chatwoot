# Chatwoot Database Environment Setup

## Overview

This setup eliminates confusion between local and production databases by:
1. **Removing local database** to prevent conflicts
2. **Using environment variables** for all database connections
3. **Dynamic account configuration** based on actual database users
4. **Easy switching** between different database environments

## Files Created

### 1. `azure_database_config.env`
Environment configuration file for Azure PostgreSQL database connection.

### 2. `switch_database.sh`
Script to easily switch between database configurations:
- `./switch_database.sh azure` - Connect to Azure production database
- `./switch_database.sh local` - Connect to local development database  
- `./switch_database.sh test` - Connect to local test database

### 3. `update_dynamic_account_env.rb`
Rails script that:
- Looks up user by email in the connected database
- Finds their account associations
- Updates environment configuration with actual IDs and tokens
- Creates access tokens if needed

### 4. `test_authentication_with_dynamic_env.rb`
Comprehensive authentication test using environment variables:
- Tests all 3 authentication methods
- Validates account and conversation access
- Provides troubleshooting guidance

## Setup Process

### Step 1: Configure for Azure Database

```bash
# Switch to Azure database configuration
./switch_database.sh azure
```

This will:
- Set environment variables for Azure PostgreSQL
- Test the database connection
- Show current configuration

### Step 2: Update Dynamic Account Information

```bash
# Load the Azure environment
source azure_database_config.env

# Update with actual user/account data from database
rails runner update_dynamic_account_env.rb

# Reload the updated configuration
source azure_database_config.env
```

This will:
- Look up `admin@voicelinkai.com` (or set `CHATWOOT_TARGET_EMAIL`)
- Find their account associations
- Create access token if needed
- Update `azure_database_config.env` with actual IDs and tokens

### Step 3: Test Authentication

```bash
# Test all authentication methods
ruby test_authentication_with_dynamic_env.rb
```

This will:
- Test `api_access_token` header method
- Test `Authorization: Bearer` method  
- Test `HTTP_API_ACCESS_TOKEN` method
- Validate account and conversation access
- Show success/failure for each method

## Environment Variables Set

After successful setup, these variables will be available:

```bash
# Database Connection
POSTGRES_HOST=chatwoot-postgres-test.postgres.database.azure.com
POSTGRES_DATABASE=chatwoot_production
POSTGRES_USERNAME=chatwoot_admin
POSTGRES_PASSWORD=VoiceLinkAI2024!
RAILS_ENV=production

# Application URLs
CHATWOOT_API_BASE_URL=https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io
FRONTEND_URL=https://chatwoot-frontend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io

# Dynamic User/Account Data (populated automatically)
CHATWOOT_ACCOUNT_ID=1
CHATWOOT_ACCOUNT_NAME="Voicelink"
CHATWOOT_USER_ID=2
CHATWOOT_USER_EMAIL=admin@voicelinkai.com
CHATWOOT_USER_TOKEN=abc123...xyz789
```

## Usage Examples

### Rails Console with Azure Database
```bash
source azure_database_config.env
rails console
```

### Run Scripts with Environment
```bash
source azure_database_config.env
rails runner your_script.rb
```

### API Calls with Environment Variables
```bash
source azure_database_config.env
curl -H "api_access_token: $CHATWOOT_USER_TOKEN" \
     "$CHATWOOT_API_BASE_URL/api/v1/accounts/$CHATWOOT_ACCOUNT_ID/conversations"
```

### SMS WebSocket Tests
```bash
source azure_database_config.env
ruby live_websocket_sms_test_auto.rb
```

## Troubleshooting

### Database Connection Issues
```bash
# Test database connection
rails runner "puts ActiveRecord::Base.connection.current_database"

# Check environment variables
echo "Database: $POSTGRES_DATABASE @ $POSTGRES_HOST"
echo "Rails Env: $RAILS_ENV"
```

### Authentication Issues
```bash
# Test API connectivity
curl -I $CHATWOOT_API_BASE_URL/api/v1/profile

# Check user exists in database
rails runner "puts User.find_by(email: '$CHATWOOT_USER_EMAIL')&.inspect"

# Verify account association
rails runner "puts AccountUser.joins(:user).where(users: {email: '$CHATWOOT_USER_EMAIL'}).inspect"
```

### Switch Back to Local Development
```bash
# If you need local development again
./switch_database.sh local
rails db:create
rails db:migrate
rails db:seed
```

## Benefits

1. **No Confusion**: Only one database active at a time
2. **Environment Driven**: All configuration via environment variables
3. **Dynamic**: Automatically uses actual database users/accounts
4. **Flexible**: Easy switching between environments
5. **Testable**: Comprehensive authentication validation
6. **Production Ready**: Uses actual Azure database and API

## Next Steps

After successful setup:
1. ✅ Database connection established
2. ✅ Authentication working
3. ✅ Environment variables configured
4. 🚀 **Ready for SMS WebSocket tests**

Run your SMS tests:
```bash
ruby live_websocket_sms_test_auto.rb
``` 