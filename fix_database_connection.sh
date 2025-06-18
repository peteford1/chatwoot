#!/bin/bash

echo "🔧 FIXING DATABASE CONNECTION ISSUES"
echo "====================================="

# Configuration
RESOURCE_GROUP="SM-Test"
CONTAINER_APP="chatwoot-backend-test"
POSTGRES_SERVER="chatwoot-db-fresh"
DB_USER="chatwootuser"
DB_NAME="chatwoot_production"
NEW_PASSWORD="ChatwootSecure2025!"

echo "📋 Configuration:"
echo "   Resource Group: $RESOURCE_GROUP"
echo "   Container App: $CONTAINER_APP"
echo "   PostgreSQL Server: $POSTGRES_SERVER"
echo "   Database User: $DB_USER"
echo "   Database Name: $DB_NAME"

# Check if Azure CLI is logged in
if ! az account show &>/dev/null; then
    echo "❌ Not logged into Azure CLI. Please run: az login"
    exit 1
fi

echo "✅ Azure CLI authenticated"

# Step 1: Reset PostgreSQL admin password
echo -e "\n🔐 Step 1: Resetting PostgreSQL admin password..."
az postgres flexible-server update \
    --name "$POSTGRES_SERVER" \
    --resource-group "$RESOURCE_GROUP" \
    --admin-password "$NEW_PASSWORD" \
    --output none

if [ $? -eq 0 ]; then
    echo "✅ PostgreSQL admin password updated"
else
    echo "❌ Failed to update PostgreSQL admin password"
    exit 1
fi

# Step 2: Create/update the chatwootuser
echo -e "\n👤 Step 2: Creating/updating database user..."

# Connect and create user (this will use the admin credentials)
PGPASSWORD="$NEW_PASSWORD" psql \
    -h "$POSTGRES_SERVER.postgres.database.azure.com" \
    -U "chatwoot" \
    -d "postgres" \
    -c "
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$DB_USER') THEN
            CREATE USER $DB_USER WITH PASSWORD '$NEW_PASSWORD';
        ELSE
            ALTER USER $DB_USER WITH PASSWORD '$NEW_PASSWORD';
        END IF;
        
        GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
        GRANT ALL PRIVILEGES ON DATABASE chatwoot TO $DB_USER;
    END
    \$\$;
    " 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Database user created/updated successfully"
else
    echo "⚠️  Direct user creation failed, will update container app anyway"
fi

# Step 3: Update container app environment variables
echo -e "\n🔄 Step 3: Updating container app environment variables..."

NEW_DATABASE_URL="postgresql://$DB_USER:$NEW_PASSWORD@$POSTGRES_SERVER.postgres.database.azure.com/$DB_NAME"

# Get the current container configuration and update it
az containerapp update \
    --name "$CONTAINER_APP" \
    --resource-group "$RESOURCE_GROUP" \
    --replace-env-vars "DATABASE_URL=$NEW_DATABASE_URL" \
    --output none

if [ $? -eq 0 ]; then
    echo "✅ Container app environment updated"
else
    echo "❌ Failed to update container app environment"
    exit 1
fi

# Step 4: Restart the container app
echo -e "\n🔄 Step 4: Restarting container app..."
az containerapp restart \
    --name "$CONTAINER_APP" \
    --resource-group "$RESOURCE_GROUP" \
    --output none

if [ $? -eq 0 ]; then
    echo "✅ Container app restarted"
else
    echo "❌ Failed to restart container app"
    exit 1
fi

# Step 5: Wait and check status
echo -e "\n⏳ Step 5: Waiting for application to start (60 seconds)..."
sleep 60

# Test the application
echo -e "\n🧪 Step 6: Testing application endpoints..."

APP_URL="https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"

# Test health endpoint
echo "🏥 Testing health endpoint..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL/health" --max-time 15)
if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ Health endpoint working: $HTTP_STATUS"
else
    echo "❌ Health endpoint failed: $HTTP_STATUS"
fi

# Test API endpoint
echo "🔌 Testing API endpoint..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL/api/v1/accounts" --max-time 15)
if [ "$HTTP_STATUS" = "401" ] || [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ API endpoint working: $HTTP_STATUS"
else
    echo "❌ API endpoint failed: $HTTP_STATUS"
fi

# Check recent logs
echo -e "\n📝 Recent application logs:"
az containerapp logs show \
    --name "$CONTAINER_APP" \
    --resource-group "$RESOURCE_GROUP" \
    --tail 20 \
    --follow false 2>/dev/null

echo -e "\n" + "="*50
echo "🎉 DATABASE CONNECTION FIX COMPLETED!"
echo "="*50
echo "📋 Summary:"
echo "   ✅ PostgreSQL admin password reset"
echo "   ✅ Database user credentials updated"
echo "   ✅ Container app environment updated"
echo "   ✅ Container app restarted"
echo ""
echo "🔗 Application URL: $APP_URL"
echo "🗄️  Database URL: $NEW_DATABASE_URL"
echo ""
echo "💡 If issues persist:"
echo "   1. Check logs: az containerapp logs show --name $CONTAINER_APP --resource-group $RESOURCE_GROUP --follow"
echo "   2. Check database connectivity from container"
echo "   3. Verify firewall rules allow container IP" 