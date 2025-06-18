# Multi-Tenant Frontend Platform App Setup

## Overview

This document explains how to create and configure a Platform App for your multi-tenant frontend to access Chatwoot via the API gateway.

## What is a Platform App?

A Platform App in Chatwoot is designed for external applications that need to manage multiple accounts and users. It provides:

- **Multi-tenant access**: Can access multiple Chatwoot accounts
- **Account management**: Create, read, update, delete accounts
- **User management**: Create users and generate SSO login links
- **Programmatic access**: API-based operations for external applications

## Setup Instructions

### Step 1: Create Platform App in Production Backend

You need to run the platform app creation script on your production Chatwoot backend. 

**Option A: Using Azure Container Apps Console**
1. Go to Azure Portal
2. Navigate to your Chatwoot backend Container App (`chatwoot-backend-test`)
3. Go to "Console" tab
4. Run the following command:

```bash
cat > /tmp/create_platform_app.rb << 'EOF'
#!/usr/bin/env ruby

puts "🚀 Creating Platform App for Multi-Tenant Frontend in Production..."

# Create the platform app
platform_app = PlatformApp.create!(
  name: "Multi-Tenant Frontend Application"
)

puts "✅ Platform App created successfully!"
puts "   ID: #{platform_app.id}"
puts "   Name: #{platform_app.name}"

# Get the access token
access_token = platform_app.access_token

puts "\n🔐 Access Token Details:"
puts "   Token: #{access_token.token}"

# Create permissibles for all existing accounts
Account.find_each do |account|
  permissible = platform_app.platform_app_permissibles.find_or_create_by!(
    permissible: account
  )
  puts "✅ Added permission for Account: #{account.name} (ID: #{account.id})"
end

puts "\n📋 Production Summary:"
puts "   Platform App: #{platform_app.name}"
puts "   Access Token: #{access_token.token}"
puts "   Permissions: #{platform_app.platform_app_permissibles.count} accounts"

puts "\n🌐 Frontend Environment Variables:"
puts "   CHATWOOT_API_ACCESS_TOKEN=#{access_token.token}"
puts "   CHATWOOT_API_BASE_URL=https://voicelinkai-gateway.eastus.cloudapp.azure.com"
EOF

# Execute the script
bundle exec rails runner /tmp/create_platform_app.rb
```

**Option B: Using kubectl (if using Kubernetes)**
```bash
kubectl exec -it <chatwoot-backend-pod> -- bundle exec rails runner /tmp/create_platform_app.rb
```

### Step 2: Save the Access Token

After running the script, you'll get an access token like:
```
Token: abc123xyz789...
```

**IMPORTANT**: Save this token securely - you'll need it for your frontend configuration.

### Step 3: Configure Your Frontend

Add these environment variables to your multi-tenant frontend application:

```bash
# Chatwoot API Configuration
CHATWOOT_API_ACCESS_TOKEN=abc123xyz789...  # Use the token from Step 2
CHATWOOT_API_BASE_URL=https://voicelinkai-gateway.eastus.cloudapp.azure.com

# Optional: For direct backend access (if needed)
CHATWOOT_BACKEND_URL=https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io
```

## Available API Endpoints

### Account Management

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/platform/api/v1/accounts` | Create new tenant account |
| GET | `/platform/api/v1/accounts/{id}` | Get account details |
| PATCH | `/platform/api/v1/accounts/{id}` | Update account |
| DELETE | `/platform/api/v1/accounts/{id}` | Delete account |

### User Management

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/platform/api/v1/users` | Create new user |
| GET | `/platform/api/v1/users/{id}` | Get user details |
| GET | `/platform/api/v1/users/{id}/login` | Get SSO login link |
| PATCH | `/platform/api/v1/users/{id}` | Update user |
| DELETE | `/platform/api/v1/users/{id}` | Delete user |

### Account User Management

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/platform/api/v1/accounts/{id}/account_users` | List account users |
| POST | `/platform/api/v1/accounts/{id}/account_users` | Add user to account |
| DELETE | `/platform/api/v1/accounts/{id}/account_users` | Remove user from account |

## Usage Examples

### 1. Create a New Tenant Account

```bash
curl -X POST \
  -H "api_access_token: YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{"name":"Acme Corporation","domain":"acme.com"}' \
  https://voicelinkai-gateway.eastus.cloudapp.azure.com/platform/api/v1/accounts
```

Response:
```json
{
  "id": 123,
  "name": "Acme Corporation",
  "domain": "acme.com",
  "status": "active",
  "created_at": "2025-06-05T01:52:19.000Z"
}
```

### 2. Create a User

```bash
curl -X POST \
  -H "api_access_token: YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe",
    "email": "john.doe@acme.com",
    "password": "SecurePassword123!",
    "display_name": "John D."
  }' \
  https://voicelinkai-gateway.eastus.cloudapp.azure.com/platform/api/v1/users
```

### 3. Add User to Account

```bash
curl -X POST \
  -H "api_access_token: YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{"user_id": 456, "role": "administrator"}' \
  https://voicelinkai-gateway.eastus.cloudapp.azure.com/platform/api/v1/accounts/123/account_users
```

### 4. Get SSO Login Link

```bash
curl -H "api_access_token: YOUR_TOKEN_HERE" \
  https://voicelinkai-gateway.eastus.cloudapp.azure.com/platform/api/v1/users/456/login
```

Response:
```json
{
  "url": "https://voicelinkai-gateway.eastus.cloudapp.azure.com/app/login?email=john.doe%40acme.com&sso_auth_token=abc123..."
}
```

## Frontend Integration Examples

### JavaScript/TypeScript

```typescript
class ChatwootPlatformAPI {
  private baseURL = process.env.CHATWOOT_API_BASE_URL;
  private token = process.env.CHATWOOT_API_ACCESS_TOKEN;

  private async request(endpoint: string, options: RequestInit = {}) {
    const response = await fetch(`${this.baseURL}${endpoint}`, {
      ...options,
      headers: {
        'api_access_token': this.token,
        'Content-Type': 'application/json',
        ...options.headers,
      },
    });
    
    if (!response.ok) {
      throw new Error(`API request failed: ${response.statusText}`);
    }
    
    return response.json();
  }

  async createAccount(data: { name: string; domain?: string }) {
    return this.request('/platform/api/v1/accounts', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async createUser(data: { name: string; email: string; password: string }) {
    return this.request('/platform/api/v1/users', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async getUserLoginLink(userId: number) {
    return this.request(`/platform/api/v1/users/${userId}/login`);
  }

  async addUserToAccount(accountId: number, userId: number, role: string = 'agent') {
    return this.request(`/platform/api/v1/accounts/${accountId}/account_users`, {
      method: 'POST',
      body: JSON.stringify({ user_id: userId, role }),
    });
  }
}

// Usage
const api = new ChatwootPlatformAPI();

// Create a new tenant
const account = await api.createAccount({ 
  name: "New Customer Corp",
  domain: "newcustomer.com" 
});

// Create a user for this tenant
const user = await api.createUser({
  name: "Admin User",
  email: "admin@newcustomer.com",
  password: "SecurePass123!"
});

// Add user to the account as administrator
await api.addUserToAccount(account.id, user.id, "administrator");

// Get login link for the user
const loginResponse = await api.getUserLoginLink(user.id);
console.log("Login URL:", loginResponse.url);
```

### React Hook Example

```typescript
import { useState, useCallback } from 'react';

interface Account {
  id: number;
  name: string;
  domain?: string;
  status: string;
}

interface User {
  id: number;
  name: string;
  email: string;
  display_name: string;
}

export function useChatwootPlatform() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const api = new ChatwootPlatformAPI();

  const createTenant = useCallback(async (tenantData: { name: string; domain?: string }) => {
    setLoading(true);
    setError(null);
    
    try {
      const account = await api.createAccount(tenantData);
      return account;
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to create tenant');
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  const createTenantUser = useCallback(async (userData: { 
    name: string; 
    email: string; 
    password: string;
    accountId: number;
    role?: string;
  }) => {
    setLoading(true);
    setError(null);
    
    try {
      // Create the user
      const user = await api.createUser({
        name: userData.name,
        email: userData.email,
        password: userData.password,
      });

      // Add user to account
      await api.addUserToAccount(userData.accountId, user.id, userData.role || 'agent');

      // Get login link
      const loginResponse = await api.getUserLoginLink(user.id);

      return {
        user,
        loginUrl: loginResponse.url,
      };
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to create user');
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  return {
    createTenant,
    createTenantUser,
    loading,
    error,
  };
}
```

## Security Considerations

1. **Token Security**: Store the access token securely using environment variables or secure credential management
2. **HTTPS Only**: Always use HTTPS for API calls
3. **Rate Limiting**: The API has rate limiting enabled - implement proper retry logic
4. **Input Validation**: Validate all user inputs before sending to the API
5. **Error Handling**: Implement proper error handling for API failures

## Troubleshooting

### Common Issues

1. **"Invalid access_token"**: Ensure the token was created in the correct environment
2. **"Non permissible resource"**: The platform app needs permissions for the specific account
3. **"RBAC: access denied"**: Check if the Application Gateway has proper routing rules

### Getting Help

If you encounter issues:
1. Check the container logs for the KrakenD gateway
2. Verify the backend container is running and accessible
3. Ensure the platform app was created in the production database

## Next Steps

1. Run the platform app creation script on your production backend
2. Configure your frontend with the generated token
3. Test the API endpoints with your frontend application
4. Implement proper error handling and user feedback
5. Set up monitoring for API usage and errors 