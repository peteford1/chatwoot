#!/bin/bash

echo "🔄 Auto SSL Certificate Monitor & Binder"
echo "========================================"
echo "Certificate: voicelinkai-cert-fresh"
echo "Domain: voicelinkai.com"
echo "Expected Token: _1y2dteupodcppef2rj8sy0bpradx6dk"
echo ""

# Verify DNS record first
current_token=$(dig TXT _acme-challenge.voicelinkai.com +short | tr -d '"')
if [ "$current_token" = "_1y2dteupodcppef2rj8sy0bpradx6dk" ]; then
    echo "✅ DNS TXT record is correct: $current_token"
else
    echo "❌ DNS TXT record mismatch!"
    echo "   Expected: _1y2dteupodcppef2rj8sy0bpradx6dk"
    echo "   Current:  $current_token"
    exit 1
fi

echo ""
echo "🔍 Monitoring certificate validation..."
echo "Will check every 30 seconds for up to 20 minutes"
echo ""

# Monitor for up to 40 checks (20 minutes)
for i in {1..40}; do
    echo "🔍 Check #$i at $(date '+%H:%M:%S')"
    
    # Get certificate status
    status=$(az containerapp env certificate list \
        --name chatwoot-env-test \
        --resource-group SM-Test \
        --query "[?name=='voicelinkai-cert-fresh'].properties.provisioningState" \
        -o tsv 2>/dev/null)
    
    echo "   Status: $status"
    
    if [ "$status" = "Succeeded" ]; then
        echo ""
        echo "🎉 CERTIFICATE VALIDATED SUCCESSFULLY!"
        echo ""
        echo "🔗 Attempting to bind certificate to hostname..."
        
        # Bind certificate to hostname
        az containerapp hostname bind \
            --hostname voicelinkai.com \
            --resource-group SM-Test \
            --name chatwoot-backend-test \
            --certificate "/subscriptions/535e2aa8-27e9-4d89-9208-be446ef89b87/resourceGroups/SM-Test/providers/Microsoft.App/managedEnvironments/chatwoot-env-test/managedCertificates/voicelinkai-cert-fresh"
        
        if [ $? -eq 0 ]; then
            echo ""
            echo "🌟 SUCCESS! SSL Certificate bound to voicelinkai.com!"
            echo "🔗 Your domain should now be accessible via HTTPS"
            echo ""
            echo "✅ Final verification - testing HTTPS access..."
            curl -I https://voicelinkai.com/api 2>/dev/null | head -3
            echo ""
            echo "🎊 SSL Setup Complete!"
            exit 0
        else
            echo "❌ Certificate binding failed"
            exit 1
        fi
    elif [ "$status" = "Failed" ]; then
        echo ""
        echo "❌ Certificate validation FAILED"
        echo "Check DNS records and certificate configuration"
        exit 1
    else
        echo "   ⏳ Still pending... waiting 30 seconds"
        sleep 30
    fi
done

echo ""
echo "⏰ Timeout: Certificate validation took longer than 20 minutes"
echo "❌ Please check Azure portal for detailed error messages"
exit 1 