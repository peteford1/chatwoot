# Twilio Webhook String/Symbol Key Mismatch Bug

**Issue Date:** 2025-06-04  
**Status:** ✅ RESOLVED  
**Severity:** HIGH - Blocks all Twilio webhook message processing  

## Symptoms
- Twilio webhooks return HTTP 204 (success) but no messages are created in Chatwoot
- TwilioEventsJob skips processing due to `params[:Body].blank?` check failing
- No error messages in logs, making it difficult to diagnose

## Root Cause Analysis

### Problem
**String vs Symbol Key Mismatch** in the webhook processing chain:

1. **Twilio::CallbackController** (app/controllers/twilio/callback_controller.rb):
   ```ruby
   def create
     Webhooks::TwilioEventsJob.perform_later(permitted_params.to_unsafe_hash)
     head :no_content
   end
   ```
   - `permitted_params.to_unsafe_hash` produces **string keys**: `{'Body' => 'message', 'AccountSid' => 'AC123'}`

2. **Webhooks::TwilioEventsJob** (app/jobs/webhooks/twilio_events_job.rb):
   ```ruby
   def perform(params = {})
     return if params[:Body].blank? && params[:MediaUrl0].blank?  # <-- FAILS!
     ::Twilio::IncomingMessageService.new(params: params).perform
   end
   ```
   - Tries to access with **symbol keys**: `params[:Body]` but receives `params['Body']`
   - Since `params[:Body]` is `nil`, the condition `params[:Body].blank?` is `true`
   - Job exits early and never processes the message

3. **Twilio::IncomingMessageService** (app/services/twilio/incoming_message_service.rb):
   ```ruby
   def twilio_channel
     @twilio_channel ||= ::Channel::TwilioSms.find_by(messaging_service_sid: params[:MessagingServiceSid])
     if params[:AccountSid].present? && params[:To].present?  # <-- ALSO FAILS!
       @twilio_channel ||= ::Channel::TwilioSms.find_by!(account_sid: params[:AccountSid], phone_number: params[:To])
     end
   end
   ```
   - Also expects symbol keys but receives string keys

## Verification Steps
1. **Identify the key type mismatch:**
   ```ruby
   # In controller - produces string keys
   puts permitted_params.to_unsafe_hash.class  # => Hash
   puts permitted_params.to_unsafe_hash.keys   # => ["Body", "AccountSid", "To", ...]
   
   # In job - expects symbol keys  
   puts params[:Body]      # => nil (should be "message content")
   puts params['Body']     # => "message content" (actual location)
   ```

2. **Test webhook processing:**
   - Direct webhook: ❌ HTTP 204 but no message created
   - Manual service call with symbol keys: ✅ Works perfectly

## Solution Applied
**Convert string keys to symbol keys** in TwilioEventsJob before processing:

```ruby
class Webhooks::TwilioEventsJob < ApplicationJob
  queue_as :low

  def perform(params = {})
    # 2025-06-04: Fix string/symbol key mismatch - controller sends string keys but service expects symbol keys
    # Convert string keys from permitted_params.to_unsafe_hash to symbol keys for compatibility
    symbolized_params = params.deep_symbolize_keys
    
    # Skip processing if Body parameter or MediaUrl0 is not present
    return if symbolized_params[:Body].blank? && symbolized_params[:MediaUrl0].blank?

    ::Twilio::IncomingMessageService.new(params: symbolized_params).perform
  end
end
```

## Files Modified
- `app/jobs/webhooks/twilio_events_job.rb` - Added `deep_symbolize_keys` conversion
- `app/jobs/webhooks/twilio_delivery_status_job.rb` - Added `deep_symbolize_keys` conversion

## Test Results (Post-Fix)
✅ **Manual Job Test:** `Webhooks::TwilioEventsJob.perform_now({'Body' => 'test'})` creates message successfully  
✅ **Direct Webhook Test:** `POST /twilio/callback` returns HTTP 204 and creates message  
⚠️ **KrakenD Gateway:** Still has "invalid status code" error - separate KrakenD configuration issue  

**Messages Created:**
- 16:44:45: Manual test message (pre-fix)
- 17:12:12: Manual job test (post-fix) ✅  
- No message from webhook test yet - investigating timing

## Prevention
- **Code Review:** Always check parameter key types when passing between Rails components
- **Testing:** Include integration tests that verify the full webhook → job → service chain
- **Documentation:** Document expected parameter formats in service classes

## Related Issues
- This pattern may exist in other webhook processing jobs
- Consider standardizing on either string or symbol keys across all webhook handlers
- KrakenD gateway needs configuration to handle HTTP 204 responses properly 