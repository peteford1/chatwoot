-- Admin Auth transformation for Chatwoot Admin API
function post_proxy(request_context)
  -- Extract user info from JWT token
  local user_id = request_context.request.headers["X-User-ID"]
  local user_role = request_context.request.headers["X-User-Role"]
  
  -- Only allow admin/administrator roles
  if user_role == "admin" or user_role == "administrator" then
    -- Add Chatwoot Admin API token
    request_context.request.headers["api_access_token"] = "DeXVYXznkBJ2RkBlq99zpg"
    
    -- Add user context for audit logging
    request_context.request.headers["X-Admin-User-ID"] = user_id
    request_context.request.headers["X-Admin-Action"] = request_context.request.method .. " " .. request_context.request.url_pattern
  else
    -- Reject non-admin requests
    request_context.response.status_code = 403
    request_context.response.body = json.encode({
      error = "Insufficient privileges",
      message = "Admin access required"
    })
    request_context.response.headers["Content-Type"] = "application/json"
    return request_context
  end
  
  -- Remove internal headers
  request_context.request.headers["X-JWT-Payload"] = nil
  request_context.request.headers["X-User-Role"] = nil
  
  return request_context
end

function response_proxy(request_context)
  -- Add security headers to admin responses
  request_context.response.headers["X-Frame-Options"] = "DENY"
  request_context.response.headers["X-Content-Type-Options"] = "nosniff"
  request_context.response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
  
  return request_context
end 