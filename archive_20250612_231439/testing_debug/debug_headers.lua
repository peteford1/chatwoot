-- debug_headers.lua
-- This script logs all headers to help debug the authentication issue

function pre_request(context)
    print("=== DEBUG: PRE-REQUEST HEADERS ===")
    local headers = context.request.headers
    
    -- Log all incoming headers
    for key, value in pairs(headers) do
        print(string.format("INCOMING HEADER: %s = %s", key, value))
    end
    
    -- Specifically check for auth headers
    local auth_headers = {
        "access-token",
        "client", 
        "uid",
        "token-type",
        "expiry",
        "authorization",
        "content-type"
    }
    
    print("=== AUTH HEADERS CHECK ===")
    for _, header in ipairs(auth_headers) do
        local value = headers[header]
        if value then
            print(string.format("AUTH HEADER FOUND: %s = %s", header, value))
        else
            print(string.format("AUTH HEADER MISSING: %s", header))
        end
    end
    
    print("=== END DEBUG PRE-REQUEST ===")
end

function post_request(context)
    print("=== DEBUG: POST-REQUEST ===")
    print(string.format("RESPONSE STATUS: %d", context.response.status_code))
    
    local response_headers = context.response.headers
    for key, value in pairs(response_headers) do
        print(string.format("RESPONSE HEADER: %s = %s", key, value))
    end
    
    print("=== END DEBUG POST-REQUEST ===")
end 