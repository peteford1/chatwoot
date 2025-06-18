#!/bin/bash

echo "🔍 Monitoring SSL Certificate Validation Progress..."
echo "=================================================="

# Certificate details
CERT_NAME="voicelinkai-cert-txt"
ENV_NAME="chatwoot-env-test"
RESOURCE_GROUP="SM-Test"
APP_NAME="chatwoot-backend-test"
HOSTNAME="voicelinkai.com"

# Function to check certificate status
check_cert_status() {
    az containerapp env certificate list \
        --name $ENV_NAME \
        --resource-group $RESOURCE_GROUP \
        --query "[?name=='$CERT_NAME'].properties.provisioningState" \
        -o tsv 2>/dev/null
}

# Function to get certificate ID
get_cert_id() {
    az containerapp env certificate list \
        --name $ENV_NAME \
        --resource-group $RESOURCE_GROUP \
        --query "[?name=='$CERT_NAME'].id" \
        -o tsv 2>/dev/null
}

# Function to bind certificate
bind_certificate() {
    local cert_id=$1
    echo "🔗 Attempting to bind certificate..."
    
    az containerapp hostname bind \
        --hostname $HOSTNAME \
        --resource-group $RESOURCE_GROUP \
        --name $APP_NAME \
        --certificate "$cert_id"
    
    return $?
}

# Main monitoring loop
max_attempts=20  # 20 attempts = ~10 minutes (30s intervals)
attempt=1

echo "📋 Certificate: $CERT_NAME"
echo "🌐 Domain: $HOSTNAME"
echo "⏱️  Max wait time: 10 minutes"
echo ""

while [ $attempt -le $max_attempts ]; do
    echo "🔍 Check #$attempt - $(date +"%H:%M:%S")"
    
    # Get current status
    status=$(check_cert_status)
    
    case "$status" in
        "Succeeded")
            echo "✅ Certificate validation completed!"
            cert_id=$(get_cert_id)
            echo "📋 Certificate ID: $cert_id"
            
            if [ -n "$cert_id" ]; then
                if bind_certificate "$cert_id"; then
                    echo ""
                    echo "🎉 SUCCESS! SSL certificate has been bound to $HOSTNAME"
                    echo ""
                    echo "🔐 Testing HTTPS access..."
                    curl -I https://$HOSTNAME/api/backend/status 2>/dev/null | head -1
                    echo ""
                    echo "✅ Your domain https://$HOSTNAME is now fully configured with SSL!"
                    exit 0
                else
                    echo "❌ Certificate binding failed. Please check manually."
                    exit 1
                fi
            else
                echo "❌ Could not retrieve certificate ID"
                exit 1
            fi
            ;;
        "Pending")
            echo "⏳ Certificate validation still pending..."
            ;;
        "Failed")
            echo "❌ Certificate validation failed!"
            echo "Please check your DNS TXT record:"
            echo "  Name: _acme-challenge.$HOSTNAME"
            echo "  Value: _8w1uni6yymqmnjy8c54hwfeknert97r"
            exit 1
            ;;
        "")
            echo "⚠️  Certificate not found or query failed"
            ;;
        *)
            echo "⚠️  Unknown status: $status"
            ;;
    esac
    
    # Wait before next check (except on last attempt)
    if [ $attempt -lt $max_attempts ]; then
        echo "⏳ Waiting 30 seconds for next check..."
        sleep 30
    fi
    
    attempt=$((attempt + 1))
done

echo ""
echo "⏰ Timeout reached after $max_attempts attempts"
echo "❌ Certificate validation is taking longer than expected"
echo ""
echo "🔧 Manual steps to complete:"
echo "1. Verify TXT record: dig TXT _acme-challenge.$HOSTNAME"
echo "2. Wait a few more minutes for validation"
echo "3. Run: ./configure_azure_domain.sh"
echo ""
echo "If issues persist, check the Azure portal for certificate status." 