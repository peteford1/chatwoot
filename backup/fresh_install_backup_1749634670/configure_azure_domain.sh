#!/bin/bash

echo "🚀 Configuring Azure Container App with custom domain..."
echo "======================================================="

echo "Step 1: Checking if domain is already added..."
existing_hostname=$(az containerapp show --name chatwoot-backend-test --resource-group SM-Test --query "properties.configuration.ingress.customDomains[?name=='voicelinkai.com'].name" -o tsv 2>/dev/null)

if [ -n "$existing_hostname" ]; then
    echo "✅ Domain voicelinkai.com is already configured"
    echo "Proceeding to SSL certificate setup..."
    domain_added=true
else
    echo "Adding custom domain to Container App..."
    az containerapp hostname add --hostname voicelinkai.com --resource-group SM-Test --name chatwoot-backend-test
    
    if [ $? -eq 0 ]; then
        echo "✅ Domain added successfully!"
        domain_added=true
    else
        echo "❌ Failed to add domain"
        domain_added=false
    fi
fi

if [ "$domain_added" = true ]; then
    echo -e "\nStep 2: Setting up SSL certificate..."
    
    # Check if certificate already exists
    existing_cert=$(az containerapp env certificate list --name chatwoot-env-test --resource-group SM-Test --query "[?properties.subjectName=='voicelinkai.com'].id" -o tsv 2>/dev/null)
    
    if [ -n "$existing_cert" ]; then
        echo "✅ Certificate already exists: $existing_cert"
        cert_id="$existing_cert"
    else
        echo "Creating new managed certificate with HTTP validation..."
        # Create managed certificate with HTTP validation
        cert_id=$(az containerapp env certificate create \
            --certificate-name voicelinkai-cert \
            --hostname voicelinkai.com \
            --resource-group SM-Test \
            --name chatwoot-env-test \
            --validation-method HTTP \
            --query id -o tsv)
        
        if [ $? -eq 0 ] && [ -n "$cert_id" ]; then
            echo "✅ Certificate created with ID: $cert_id"
        else
            echo "❌ Failed to create SSL certificate with HTTP validation"
            echo "Trying alternative approach with CNAME validation..."
            
            # Try TXT validation as fallback (supported for this domain)
            cert_id=$(az containerapp env certificate create \
                --certificate-name voicelinkai-cert-txt \
                --hostname voicelinkai.com \
                --resource-group SM-Test \
                --name chatwoot-env-test \
                --validation-method TXT \
                --query id -o tsv)
            
            if [ $? -eq 0 ] && [ -n "$cert_id" ]; then
                echo "✅ Certificate created with TXT validation: $cert_id"
                echo "⚠️  You may need to add additional DNS TXT records for validation"
            else
                echo "❌ Both HTTP and TXT validation failed"
                echo ""
                echo "🚨 CRITICAL: DNS A record mismatch detected!"
                echo "   Expected: voicelinkai.com → 51.8.58.201"
                echo "   Current:  voicelinkai.com → 64.227.102.80"
                echo ""
                echo "Please update your DNS A record to point to 51.8.58.201"
                echo "Then wait 5-10 minutes for DNS propagation and try again"
                exit 1
            fi
        fi
    fi
    
    if [ -n "$cert_id" ]; then
        echo -e "\nStep 3: Binding certificate to hostname..."
        az containerapp hostname bind \
            --hostname voicelinkai.com \
            --resource-group SM-Test \
            --name chatwoot-backend-test \
            --certificate "$cert_id"
        
        if [ $? -eq 0 ]; then
            echo -e "\n✅ SSL certificate configured and bound!"
            echo -e "\n🎉 Your domain https://voicelinkai.com is now ready!"
            
            echo -e "\nNext steps:"
            echo "1. Update your Chatwoot configuration to use the new domain"
            echo "2. Update your gateway configuration"
            echo "3. Test the domain access"
            
            echo -e "\nTesting domain access..."
            curl -I https://voicelinkai.com/api/backend/status 2>/dev/null | head -1
        else
            echo "❌ Failed to bind certificate to hostname"
            echo "You may need to check the certificate status and try again"
        fi
    fi
else
    echo "❌ Cannot proceed without domain configuration. Please check:"
    echo "  - TXT record: asuid.voicelinkai.com → 4395C0037B6AE3D7E3E337355B4FFF8D5DB2C448F197F6155A4B7299D98D9182"
    echo "  - A record: voicelinkai.com → 51.8.58.201 (currently: 64.227.102.80)"
    echo "  - DNS propagation (wait 5-10 minutes after DNS changes)"
    echo ""
    echo "To check DNS propagation:"
    echo "  dig TXT asuid.voicelinkai.com"
    echo "  dig A voicelinkai.com"
    echo ""
    echo "Note: Your A record currently points to 64.227.102.80 but should point to 51.8.58.201"
fi 