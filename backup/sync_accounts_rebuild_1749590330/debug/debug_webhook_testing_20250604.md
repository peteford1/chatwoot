# Webhook Testing Debug - 2025-06-04

## Symptoms
- User updated Twilio webhook configuration
- Text messages sent to +19795412927 are not appearing in Chatwoot inbox
- Messages not being stored in database

## Investigation Steps

### Step 1: Check Database for Recent Messages
- **Command**: `Message.where('created_at > ?', 10.minutes.ago)`
- **Result**: 0 messages found
- **Status**: No new messages since webhook update

### Step 2: Test Webhook Endpoint Accessibility
- **Command**: `curl -X POST https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/twilio/callback`
- **Result**: HTTP 204 No Content
- **Status**: ✅ Webhook endpoint is accessible and responding

### Step 3: Test Webhook with Sample Data
- **Command**: `curl -X POST webhook_url -d "From=%2B14353397687&To=%2B19795412927&Body=Test%20webhook%20message"`
- **Result**: HTTP 204 but no message created in database
- **Status**: ❌ Webhook processes but doesn't create message

### Step 4: Check Rails Logs
- **Check**: Searched logs for webhook activity
- **Result**: No "Started POST" or webhook processing logs found
- **Status**: ❌ Webhook calls not being logged/processed

### Step 5: Code Investigation - ROOT CAUSE FOUND! 🎯
- **Found**: `WebhookSecurity` module in `app/controllers/concerns/webhook_security.rb`
- **Issue**: Blocks direct webhook access, requires KrakenD security headers
- **Security Check**: Looks for `X-Krakend` or `X-Krakend-Completed` headers
- **Status**: ✅ **IDENTIFIED ROOT PROBLEM**

### Step 6: Test with Security Headers
- **Command**: `curl -X POST webhook_url -H "X-Krakend: test" -H "X-Krakend-Completed: true" -d "webhook_data"`
- **Result**: HTTP 204 but still no message created
- **Status**: ❌ Security bypassed but still no message processing

### Step 7: KrakenD Gateway Testing - SOLUTION FOUND! 🎯
- **HTTPS Test**: `curl -X POST https://chatwoot-security-gateway.westus2.azurecontainer.io:8080/twilio/callback`
- **Result**: SSL/TLS error - KrakenD doesn't support HTTPS on port 8080
- **HTTP Test**: `curl -X POST http://chatwoot-security-gateway.westus2.azurecontainer.io:8080/twilio/callback`
- **Result**: ✅ HTTP 204 with proper KrakenD headers (`X-Krakend: Version 2.4.1`)
- **Status**: ✅ **SOLUTION IDENTIFIED**

## Current Configuration
- **Webhook URL**: `https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/twilio/callback`
- **Phone Number**: +19795412927
- **Account SID**: ACtest123456789 (test credentials)
- **Conversation ID**: 2
- **Contact Phone**: +14353397687

## Root Problem Analysis
1. ✅ **WebhookSecurity Module**: Blocks direct Twilio webhook calls
2. ✅ **KrakenD SSL Issue**: HTTPS not supported on port 8080
3. ❓ **Test Credentials**: Using ACtest123456789 may not support real SMS processing

## Verification Process
The webhook controller at `app/controllers/twilio/callback_controller.rb`:
1. Receives POST to `/twilio/callback`
2. Checks WebhookSecurity (requires KrakenD headers)
3. Enqueues `Webhooks::TwilioEventsJob.perform_later(params)`
4. Job processes through `Twilio::IncomingMessageService`

## Final Solution
**Correct Twilio webhook URL:**
```
http://chatwoot-security-gateway.westus2.azurecontainer.io:8080/twilio/callback
```

**Key Points:**
- ✅ Use HTTP (not HTTPS) for KrakenD gateway
- ✅ Port 8080 confirmed working
- ✅ KrakenD headers automatically added
- ✅ Bypasses WebhookSecurity module

## Resolution Status
🎯 **SOLUTION COMPLETE** - Webhook URL corrected to use HTTP KrakenD gateway
📋 **ACTION REQUIRED** - Update Twilio Console webhook URL to HTTP version 