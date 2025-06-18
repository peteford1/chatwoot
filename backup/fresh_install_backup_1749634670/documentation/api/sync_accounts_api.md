# SyncAccounts API Documentation

**Version:** 1.0.0  
**Created:** 2025-06-10 13:25:00  
**Purpose:** Synchronize users between external systems and Chatwoot accounts

## Overview

The SyncAccounts service provides a REST API endpoint for synchronizing user data between external systems (like Store Management systems) and Chatwoot. It handles user creation, updates, role assignment, and inbox membership management.

## Base URL

```
https://your-chatwoot-domain.com/api/v1/accounts/{account_id}/sync_accounts
```

## Authentication

**Current Status:** Authentication is disabled for testing  
**Future:** Will require API access token or Bearer token authentication

## Endpoints

### 1. Sync Users

**Endpoint:** `POST /api/v1/accounts/{account_id}/sync_accounts/sync`  
**Purpose:** Synchronize users between external system and Chatwoot

#### Request Format

```json
{
  "sync_accounts": {
    "sm_store_id": "store_123",
    "store_name": "Example Store",
    "chatwoot_account_id": 1,
    "users": [
      {
        "sm_user_id": "user_456", 
        "name": "John Doe",
        "username": "john.doe",
        "chatwoot_user_id": null
      },
      {
        "sm_user_id": "user_789",
        "name": "Jane Smith",
        "username": "jane.smith", 
        "chatwoot_user_id": 5
      }
    ]
  }
}
```

#### Response Format

```json
{
  "success": true,
  "data": {
    "sm_store_id": "store_123",
    "store_name": "Example Store",
    "chatwoot_account_id": 1,
    "account_changed": false,
    "users": [
      {
        "sm_user_id": "user_456",
        "name": "John Doe",
        "username": "john.doe", 
        "chatwoot_user_id": 25,
        "changed_flag": true
      },
      {
        "sm_user_id": "user_789",
        "name": "Jane Smith",
        "username": "jane.smith",
        "chatwoot_user_id": 5,
        "changed_flag": false
      }
    ],
    "processed_at": "2025-06-10T20:30:00Z",
    "summary": {
      "total_users": 2,
      "changed_users": 1,
      "errors": 0
    }
  }
}
```

#### Field Descriptions

**Request Fields:**
- `sm_store_id` (string, required): External store identifier
- `store_name` (string, required): Name of the store/account
- `chatwoot_account_id` (integer, required): Chatwoot account ID to sync with
- `users` (array, required): Array of user objects
  - `sm_user_id` (string, required): External user identifier
  - `name` (string, required): User's display name
  - `username` (string, required): Username for email generation and lookups
  - `chatwoot_user_id` (integer, optional): Existing Chatwoot user ID

**Response Fields:**
- `account_changed` (boolean): Whether account details were updated
- `changed_flag` (boolean): Whether user's chatwoot_user_id was created or changed
- `processed_at` (string): ISO 8601 timestamp of processing
- `summary`: Statistics about the sync operation

### 2. Health Check

**Endpoint:** `GET /api/v1/accounts/{account_id}/sync_accounts/health`  
**Purpose:** Check service health status

#### Response

```json
{
  "success": true,
  "service": "SyncAccounts",
  "status": "healthy", 
  "timestamp": "2025-06-10T20:30:00Z",
  "version": "1.0.0"
}
```

### 3. Service Information

**Endpoint:** `GET /api/v1/accounts/{account_id}/sync_accounts/info`  
**Purpose:** Get detailed service information and API documentation

#### Response

Returns comprehensive service information including endpoints, input/output formats, and usage examples.

## Business Logic

### User Processing Rules

1. **Find Existing User:**
   - First tries to find by `chatwoot_user_id` if provided and exists in the account
   - If chatwoot_user_id not found or not in account, tries username lookup within account
   - If username found in account with different ID, returns correct user and sets changed_flag
   - Falls back to email lookup if needed
   - Creates new user if none found

2. **Username-Based Lookup:**
   - **NEW:** If provided chatwoot_user_id doesn't exist in account, searches by username
   - Looks for users in the account with matching username in email or name fields  
   - Returns correct chatwoot_user_id when username match found
   - **This solves the scenario where external system has wrong ID but correct username**

3. **Create New User:**
   - Creates new user if not found by any method
   - Generates email as `{username}@voicelinkai.com`
   - Sets random password and confirms account

4. **User Updates:**
   - Reactivates inactive users automatically
   - Updates user name and email if username changed
   - Ensures data consistency between systems

5. **Role Assignment:**
   - Ensures all users have administrator role
   - Adds users to account if not already members

6. **Inbox Assignment:**
   - Assigns all active users to all inboxes in the account
   - Only assigns to WebWidget, API, and TwilioSms channels

### Changed Flag Logic

A user's `changed_flag` is set to `true` when:
- New user is created (chatwoot_user_id was null/empty)
- Existing chatwoot_user_id doesn't exist and new user is created
- **NEW:** Wrong chatwoot_user_id provided but correct user found via username lookup
- User is reactivated from inactive status
- User details (name/email) are updated

## Error Handling

### Validation Errors (400 Bad Request)

```json
{
  "success": false,
  "error": "Validation Error",
  "message": "Missing required fields: store_name, users"
}
```

### Not Found Errors (404 Not Found) 

```json
{
  "success": false,
  "error": "Not Found",
  "message": "Chatwoot account with ID 999 not found"
}
```

### Server Errors (500 Internal Server Error)

```json
{
  "success": false,
  "error": "Internal Server Error", 
  "message": "An unexpected error occurred"
}
```

## Usage Examples

### cURL Example

```bash
curl -X POST \
  https://your-domain.com/api/v1/accounts/1/sync_accounts/sync \
  -H "Content-Type: application/json" \
  -d '{
    "sync_accounts": {
      "sm_store_id": "store_123",
      "store_name": "Test Store",
      "chatwoot_account_id": 1,
      "users": [
        {
          "sm_user_id": "user_001",
          "name": "Alice Johnson",
          "username": "alice.johnson",
          "chatwoot_user_id": null
        }
      ]
    }
  }'
```

### JavaScript Example

```javascript
const response = await fetch('/api/v1/accounts/1/sync_accounts/sync', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    sync_accounts: {
      sm_store_id: 'store_123',
      store_name: 'Test Store', 
      chatwoot_account_id: 1,
      users: [
                 {
           sm_user_id: 'user_001',
           name: 'Alice Johnson',
           username: 'alice.johnson',
           chatwoot_user_id: null
         }
      ]
    }
  })
});

const result = await response.json();
console.log(result);
```

## Testing

### Health Check Test

```bash
curl https://your-domain.com/api/v1/accounts/1/sync_accounts/health
```

### Service Info Test

```bash  
curl https://your-domain.com/api/v1/accounts/1/sync_accounts/info
```

## Integration Notes

1. **Email Generation:** Users are created with emails like `{username}@voicelinkai.com`
2. **Password Management:** New users get random passwords - implement password reset flow
3. **Idempotency:** Service is idempotent - safe to call multiple times with same data
4. **Logging:** All operations are logged via custom logger to `custom/logs/`
5. **Environment Support:** Works across local/test/stage/prod environments

## Security Considerations

1. **Authentication:** Currently disabled - implement before production use
2. **Authorization:** Verify caller has permission to modify specific account
3. **Rate Limiting:** Consider implementing rate limits for high-volume usage
4. **Input Validation:** All inputs are validated for required fields and types
5. **Error Disclosure:** Sensitive error details only shown in development mode

## Monitoring

- **Health Endpoint:** Use for automated health checks
- **Custom Logging:** Monitor `custom/logs/` for detailed operation logs  
- **Response Times:** Monitor sync endpoint performance
- **Error Rates:** Track error responses and types

## Future Enhancements

1. **Batch Processing:** Support for larger user sets
2. **Async Processing:** Background job processing for large syncs
3. **Webhook Notifications:** Notify external systems of sync completion
4. **Custom Field Mapping:** Support for additional user attributes
5. **Selective Sync:** Option to sync only specific user subsets 