-- Auth transformation for Chatwoot Widget API (No-Op encoding)
function post_proxy(request_context)
  -- Handle widget authentication using website tokens instead of JWT
  local auth_header = request_context.request.headers["Authorization"]
  
  -- For widget endpoints, pass through Authorization header for website token validation
  if string.match(request_context.request.url_pattern, "/api/v1/widget/") and auth_header then
    -- Extract website token from Authorization header if present
    local website_token = string.match(auth_header, "Bearer%s+(.+)")
    if website_token then
      request_context.request.headers["X-Website-Token"] = website_token
    end
  end
  
  -- Add security headers for widget API
  request_context.request.headers["X-Widget-API"] = "true"
  request_context.request.headers["X-Forwarded-Proto"] = "https"
  
  return request_context
end

function response_proxy(request_context)
  -- Add security headers to widget API responses
  request_context.response.headers["X-Content-Type-Options"] = "nosniff"
  request_context.response.headers["X-Frame-Options"] = "SAMEORIGIN"
  request_context.response.headers["X-Widget-Gateway"] = "VoiceLink-AI"
  
  return request_context
end 