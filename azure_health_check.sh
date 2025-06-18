#!/bin/bash

echo "🔍 AZURE CHATWOOT DEPLOYMENT HEALTH CHECK"
echo "=========================================="

# Azure resource details
RESOURCE_GROUP="SM-Test"
CONTAINER_APP="chatwoot-backend-test"
POSTGRES_SERVER="chatwoot-postgres-test"
REDIS_NAME="chatwoot-redis-test"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if Azure CLI is logged in
echo "🔐 Checking Azure CLI authentication..."
if ! az account show &>/dev/null; then
    echo -e "${RED}❌ Not logged into Azure CLI. Please run: az login${NC}"
    exit 1
fi

ACCOUNT_INFO=$(az account show --query "{name:name, id:id}" -o table 2>/dev/null)
echo -e "${GREEN}✅ Azure CLI authenticated${NC}"
echo "$ACCOUNT_INFO"

echo -e "\n📋 Resource Group: ${BLUE}$RESOURCE_GROUP${NC}"

# Function to check resource status
check_resource_status() {
    local resource_type="$1"
    local resource_name="$2"
    local additional_params="$3"
    
    echo -e "\n🔍 Checking $resource_type: ${BLUE}$resource_name${NC}"
    
    if az $resource_type show --name "$resource_name" --resource-group "$RESOURCE_GROUP" $additional_params &>/dev/null; then
        echo -e "${GREEN}✅ $resource_type exists${NC}"
        return 0
    else
        echo -e "${RED}❌ $resource_type not found or inaccessible${NC}"
        return 1
    fi
}

# Check Container App
echo -e "\n" + "="*50
echo "🐳 CONTAINER APP STATUS"
echo "="*50

if check_resource_status "containerapp" "$CONTAINER_APP"; then
    echo "📊 Getting detailed Container App status..."
    
    # Get container app details
    CONTAINER_STATUS=$(az containerapp show \
        --name "$CONTAINER_APP" \
        --resource-group "$RESOURCE_GROUP" \
        --query "{
            provisioningState: properties.provisioningState,
            runningStatus: properties.runningStatus,
            fqdn: properties.configuration.ingress.fqdn,
            replicas: properties.template.scale,
            cpu: properties.template.containers[0].resources.cpu,
            memory: properties.template.containers[0].resources.memory
        }" \
        -o table 2>/dev/null)
    
    echo "$CONTAINER_STATUS"
    
    # Get revision status
    echo -e "\n📦 Container App Revisions:"
    az containerapp revision list \
        --name "$CONTAINER_APP" \
        --resource-group "$RESOURCE_GROUP" \
        --query "[].{Name:name, Active:properties.active, CreatedTime:properties.createdTime, Replicas:properties.replicas}" \
        -o table 2>/dev/null
    
    # Get logs (last 50 lines)
    echo -e "\n📝 Recent Container Logs (last 50 lines):"
    az containerapp logs show \
        --name "$CONTAINER_APP" \
        --resource-group "$RESOURCE_GROUP" \
        --tail 50 \
        --follow false 2>/dev/null || echo -e "${YELLOW}⚠️  Could not retrieve logs${NC}"
fi

# Check PostgreSQL
echo -e "\n" + "="*50
echo "🗄️  POSTGRESQL STATUS"
echo "="*50

if check_resource_status "postgres server" "$POSTGRES_SERVER"; then
    echo "📊 Getting PostgreSQL details..."
    
    POSTGRES_STATUS=$(az postgres server show \
        --name "$POSTGRES_SERVER" \
        --resource-group "$RESOURCE_GROUP" \
        --query "{
            state: userVisibleState,
            version: version,
            sku: sku.name,
            storage: storageProfile.storageMB,
            fqdn: fullyQualifiedDomainName
        }" \
        -o table 2>/dev/null)
    
    echo "$POSTGRES_STATUS"
    
    # Check firewall rules
    echo -e "\n🔥 PostgreSQL Firewall Rules:"
    az postgres server firewall-rule list \
        --server-name "$POSTGRES_SERVER" \
        --resource-group "$RESOURCE_GROUP" \
        --query "[].{Name:name, StartIP:startIpAddress, EndIP:endIpAddress}" \
        -o table 2>/dev/null
fi

# Check Redis
echo -e "\n" + "="*50
echo "🔴 REDIS STATUS"
echo "="*50

if check_resource_status "redis" "$REDIS_NAME"; then
    echo "📊 Getting Redis details..."
    
    REDIS_STATUS=$(az redis show \
        --name "$REDIS_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "{
            provisioningState: provisioningState,
            redisVersion: redisVersion,
            sku: sku.name,
            port: port,
            sslPort: sslPort,
            hostName: hostName
        }" \
        -o table 2>/dev/null)
    
    echo "$REDIS_STATUS"
fi

# Test application endpoints
echo -e "\n" + "="*50
echo "🌐 APPLICATION ENDPOINT TESTS"
echo "="*50

APP_URL="https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"

echo "🔗 Testing application endpoints..."

# Test main health endpoint
echo -e "\n🏥 Health Check:"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL/health" --max-time 10)
if [ "$HTTP_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ Health endpoint: $HTTP_STATUS${NC}"
else
    echo -e "${RED}❌ Health endpoint: $HTTP_STATUS${NC}"
fi

# Test API endpoint
echo -e "\n🔌 API Check:"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL/api/v1/accounts" --max-time 10)
if [ "$HTTP_STATUS" = "401" ]; then
    echo -e "${GREEN}✅ API endpoint responding (401 expected without auth): $HTTP_STATUS${NC}"
elif [ "$HTTP_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ API endpoint responding: $HTTP_STATUS${NC}"
else
    echo -e "${RED}❌ API endpoint: $HTTP_STATUS${NC}"
fi

# Test platform API
echo -e "\n🏢 Platform API Check:"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL/platform/api/v1/accounts" --max-time 10)
if [ "$HTTP_STATUS" = "401" ]; then
    echo -e "${GREEN}✅ Platform API responding (401 expected without auth): $HTTP_STATUS${NC}"
elif [ "$HTTP_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ Platform API responding: $HTTP_STATUS${NC}"
else
    echo -e "${RED}❌ Platform API: $HTTP_STATUS${NC}"
fi

# Test super admin
echo -e "\n👑 Super Admin Check:"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL/super_admin/sign_in" --max-time 10)
if [ "$HTTP_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ Super Admin interface: $HTTP_STATUS${NC}"
else
    echo -e "${RED}❌ Super Admin interface: $HTTP_STATUS${NC}"
fi

# Check DNS resolution
echo -e "\n🌍 DNS Resolution Check:"
if nslookup chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io &>/dev/null; then
    echo -e "${GREEN}✅ DNS resolution working${NC}"
else
    echo -e "${RED}❌ DNS resolution failed${NC}"
fi

# Summary
echo -e "\n" + "="*50
echo "📊 HEALTH CHECK SUMMARY"
echo "="*50

echo -e "\n🎯 Quick Actions if Issues Found:"
echo "1. If Container App is down:"
echo "   az containerapp restart --name $CONTAINER_APP --resource-group $RESOURCE_GROUP"

echo -e "\n2. If PostgreSQL is down:"
echo "   az postgres server restart --name $POSTGRES_SERVER --resource-group $RESOURCE_GROUP"

echo -e "\n3. If Redis is down:"
echo "   az redis force-reboot --name $REDIS_NAME --resource-group $RESOURCE_GROUP --reboot-type AllNodes"

echo -e "\n4. Check recent deployments:"
echo "   az containerapp revision list --name $CONTAINER_APP --resource-group $RESOURCE_GROUP"

echo -e "\n5. View live logs:"
echo "   az containerapp logs show --name $CONTAINER_APP --resource-group $RESOURCE_GROUP --follow"

echo -e "\n📞 If all services show as running but app is still down:"
echo "   - Check application logs for errors"
echo "   - Verify environment variables"
echo "   - Check database connectivity from container"
echo "   - Restart the container app"

echo -e "\n✅ Health check completed!" 