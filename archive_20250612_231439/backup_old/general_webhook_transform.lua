-- General Webhook transformation for KrakenD
-- Handles webhook security validation and request transformation for multiple sources

function post_proxy(request_context)
  -- Get headers for validation
  local user_agent = request_context.request.headers["User-Agent"]
  local content_type = request_context.request.headers["Content-Type"]
  
  -- Determine webhook source based on User-Agent and path
  local webhook_source = "unknown"
  local request_path = request_context.request.url_pattern or ""
  
  if user_agent then
    if string.match(user_agent, "TwilioProxy") or string.match(user_agent, "Twilio") then
      webhook_source = "twilio"
    elseif string.match(user_agent, "facebookexternalua") then
      webhook_source = "facebook"
    elseif string.match(user_agent, "^WhatsApp/") then
      webhook_source = "whatsapp"
    elseif string.match(user_agent, "^TelegramBot") then
      webhook_source = "telegram"
    elseif string.match(user_agent, "^LineBotWebhook") then
      webhook_source = "line"
    elseif string.match(user_agent, "curl/") and string.match(request_path, "/webhooks/") then
      webhook_source = "test" -- Allow curl for testing
    end
  end
  
  -- Check if path indicates webhook endpoint  
  if string.match(request_path, "/webhooks/") then
    webhook_source = "generic" -- Allow all webhook endpoints
  elseif string.match(request_path, "/twilio/") then
    webhook_source = "twilio" -- Always allow Twilio endpoints
  end
  
  -- Allow webhooks from known sources or generic webhook endpoints
  if webhook_source ~= "unknown" then
    -- Add security headers for webhook
    request_context.request.headers["X-Webhook-Source"] = webhook_source
    request_context.request.headers["X-Forwarded-For-Real"] = request_context.request.headers["X-Forwarded-For"]
    
    -- Log webhook for monitoring
    request_context.request.headers["X-Webhook-Timestamp"] = os.time()
    
    -- Preserve signature headers for validation
    local signature_headers = {
      "X-Twilio-Signature",
      "X-Hub-Signature",
      "X-Hub-Signature-256",
      "X-Line-Signature",
      "X-Telegram-Bot-Api-Secret-Token"
    }
    
    for _, header in ipairs(signature_headers) do
      if request_context.request.headers[header] then
        request_context.request.headers[header .. "-Verified"] = "pending"
      end
    end
    
  else
    -- Block unknown webhook requests
    request_context.response.status_code = 403
    request_context.response.body = json.encode({
      error = "Forbidden",
      message = "Unknown webhook source"
    })
    request_context.response.headers["Content-Type"] = "application/json"
    return request_context
  end
  
  -- Set request encoding for form data
  if content_type and string.match(content_type, "application/x%-www%-form%-urlencoded") then
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