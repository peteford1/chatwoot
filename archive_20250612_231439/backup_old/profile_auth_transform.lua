-- Profile authentication header transformation for Chatwoot API
function post_proxy(request_context)
  -- Debug: Log incoming headers
  print("=== Profile Auth Transform Debug ===")
  print("URL Pattern: " .. (request_context.request.url_pattern or "nil"))
  
  -- Get authentication headers from the incoming request
  local access_token = request_context.request.headers["access-token"] or request_context.request.headers["Access-Token"]
  local client = request_context.request.headers["client"] or request_context.request.headers["Client"]
  local uid = request_context.request.headers["uid"] or request_context.request.headers["Uid"]
  local token_type = request_context.request.headers["token-type"] or request_context.request.headers["Token-Type"]
  local expiry = request_context.request.headers["expiry"] or request_context.request.headers["Expiry"]
  
  -- Debug: Log found headers
  print("access-token: " .. (access_token or "nil"))
  print("client: " .. (client or "nil"))
  print("uid: " .. (uid or "nil"))
  print("token-type: " .. (token_type or "nil"))
  print("expiry: " .. (expiry or "nil"))
  
  -- Ensure headers are forwarded to backend
  if access_token then
    request_context.request.headers["access-token"] = access_token
  end
  if client then
    request_context.request.headers["client"] = client
  end
  if uid then
    request_context.request.headers["uid"] = uid
  end
  if token_type then
    request_context.request.headers["token-type"] = token_type
  end
  if expiry then
    request_context.request.headers["expiry"] = expiry
  end
  
  -- Add additional headers for debugging
  request_context.request.headers["X-Profile-Auth"] = "true"
  request_context.request.headers["X-Forwarded-Proto"] = "https"
  
  print("=== End Profile Auth Transform ===")
  return request_context
end

function response_proxy(request_context)
  -- Add debug headers to response
  request_context.response.headers["X-Profile-Gateway"] = "VoiceLink-AI"
  
  return request_context
end 