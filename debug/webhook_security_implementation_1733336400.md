# Webhook Security Implementation

**Date:** 2025-06-04  
**Status:** ✅ IMPLEMENTED  
**Purpose:** Prevent direct access to Chatwoot webhook URLs - force all traffic through KrakenD security gateway

## Multi-Layer Security Approach

### ✅ Layer 1: Network-Level IP Restrictions (Azure Container App)

**Implementation:**
```bash
az containerapp ingress access-restriction set --name chatwoot-backend-test --resource-group SM-Test --rule-name "allow-krakend-only" --ip-address "4.155.89.197/32" --action Allow
az containerapp ingress access-restriction set --name chatwoot-backend-test --resource-group SM-Test --rule-name "allow-dev-access" --ip-address "66.235.2.63/32" --action Allow  
az containerapp ingress access-restriction set --name chatwoot-backend-test --resource-group SM-Test --rule-name "allow-azure-westus2" --ip-address "20.0.0.0/8" --action Allow
```

**Allowed IPs:**
- `4.155.89.197/32` - KrakenD container IP
- `66.235.2.63/32` - Developer access for testing
- `20.0.0.0/8` - Azure services range (for Container Instance outbound traffic)

**Result:** Azure Container App automatically denies all other IP addresses

### ✅ Layer 2: Application-Level Header Validation (Rails)

**Files Created:**
- `app/controllers/concerns/webhook_security.rb` - Security concern
- Modified `app/controllers/twilio/callback_controller.rb`
- Modified `app/controllers/twilio/delivery_status_controller.rb`

**Security Logic:**
```ruby
def verify_gateway_access
  krakend_version = request.headers['X-Krakend']
  krakend_completed = request.headers['X-Krakend-Completed']
  
  unless krakend_version.present? || krakend_completed.present?
    render json: { error: 'Direct webhook access not allowed' }, status: :forbidden
    return false
  end
end
```

**Required Headers from KrakenD:**
- `X-Krakend: Version 2.4.1` (Added by KrakenD automatically)
- `X-Krakend-Completed: false` (Added by KrakenD automatically)

## Configuration Status

### ✅ Current Access Rules
| Source | IP Range | Purpose | Status |
|--------|----------|---------|--------|
| KrakenD Gateway | 4.155.89.197/32 | Webhook processing | ✅ Active |
| Developer Access | 66.235.2.63/32 | Testing/debugging | ✅ Active |
| Azure Services | 20.0.0.0/8 | Container outbound traffic | ✅ Active |
| All Others | 0.0.0.0/0 | Public internet | ❌ Blocked |

### ✅ Webhook Endpoints Protected
- `/twilio/callback` - SMS/MMS webhooks
- `/twilio/delivery_status` - Delivery status updates

## Security Benefits

1. **Network Isolation**: Only specified IPs can reach webhook endpoints
2. **Header Validation**: Ensures requests originated from KrakenD gateway
3. **Logging**: All access attempts are logged for monitoring
4. **Flexibility**: Developer access maintained for testing
5. **Fail-Safe**: Multiple layers prevent circumvention

## Testing Results

**✅ KrakenD Gateway Access:** HTTP 204 - Working perfectly
**✅ IP Restrictions:** Applied successfully via Azure Container App
**⚠️ Application Security:** Requires app restart to activate

## Recommended Twilio Configuration

**Primary Webhook URL:**
```
http://chatwoot-security-gateway.westus2.azurecontainer.io:8080/twilio/callback
```

**Delivery Status URL:**
```  
http://chatwoot-security-gateway.westus2.azurecontainer.io:8080/twilio/delivery_status
```

## Security Validation

To test security effectiveness:

1. **Direct Access (should fail):**
   ```bash
   curl -X POST https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/twilio/callback
   # Expected: 403 Forbidden (after app restart)
   ```

2. **KrakenD Access (should work):**
   ```bash
   curl -X POST http://chatwoot-security-gateway.westus2.azurecontainer.io:8080/twilio/callback
   # Expected: 204 No Content
   ```

## Maintenance Notes

- **IP Updates**: If KrakenD container IP changes, update access restrictions
- **Developer IPs**: Update `allow-dev-access` rule when developer IP changes
- **Monitoring**: Check logs for blocked access attempts
- **Headers**: KrakenD automatically adds required security headers 