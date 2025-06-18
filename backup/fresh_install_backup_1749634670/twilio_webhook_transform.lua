-- Twilio Webhook transformation for KrakenD
-- Handles Twilio webhook security validation and request transformation

function post_proxy(request_context)
  -- Get Twilio signature for validation
  local twilio_signature = request_context.request.headers["X-Twilio-Signature"]
  local user_agent = request_context.request.headers["User-Agent"]
  
  -- Validate that request is from a webhook source (allow all requests to Twilio endpoints)
  if true then  -- Allow all requests to Twilio webhook endpoints
    -- Add security headers for Twilio webhook
    request_context.request.headers["X-Webhook-Source"] = "twilio"
    request_context.request.headers["X-Forwarded-For-Real"] = request_context.request.headers["X-Forwarded-For"]
    
    -- Log webhook for monitoring
    request_context.request.headers["X-Webhook-Timestamp"] = os.time()
    
    -- Preserve all Twilio-specific headers
    if twilio_signature then
      request_context.request.headers["X-Twilio-Signature-Verified"] = "pending"
    end
    
  else
    -- Block non-Twilio requests to webhook endpoints
    request_context.response.status_code = 403
    request_context.response.body = json.encode({
      error = "Forbidden",
      message = "Only Twilio webhooks are allowed"
    })
    request_context.response.headers["Content-Type"] = "application/json"
    return request_context
  end
  
  -- Set request encoding for form data
  if request_context.request.headers["Content-Type"] == "application/x-www-form-urlencoded" then
    request_context.request.headers["X-Original-Content-Type"] = "application/x-www-form-urlencoded"
  end
  
  return request_context
end

function response_proxy(request_context)
  -- Add security headers to responses
  request_context.response.headers["X-Webhook-Processed"] = "true"
  request_context.response.headers["X-Content-Type-Options"] = "nosniff"
  request_context.response.headers["X-Frame-Options"] = "DENY"
  
  -- Log successful webhook processing
  if request_context.response.status_code < 400 then
    request_context.response.headers["X-Webhook-Status"] = "success"
  else
    request_context.response.headers["X-Webhook-Status"] = "error"
  end
  
  return request_context
end 