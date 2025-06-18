# SyncAccounts Service Setup

**Service:** User synchronization between external systems and Chatwoot  
**Created:** 2025-06-10 13:35:00  
**Status:** Ready for testing (authentication disabled)

## Quick Start

### 1. File Structure Created
```
custom/
├── services/sync_accounts_service.rb          # Main service logic
├── controllers/api/v1/sync_accounts_controller.rb  # REST API endpoint
├── documentation/api/sync_accounts_api.md     # Full API documentation
└── scripts/testing/test_sync_accounts.rb      # Test script
```

### 2. Routes Added
Added to `config/routes.rb` inside API v1 namespace:
```ruby
resources :sync_accounts, only: [] do
  collection do
    post :sync, to: 'sync_accounts#sync'
    get :health, to: 'sync_accounts#health'  
    get :info, to: 'sync_accounts#info'
  end
end
```

### 3. Available Endpoints

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/api/v1/accounts/{id}/sync_accounts/sync` | Synchronize users |
| GET | `/api/v1/accounts/{id}/sync_accounts/health` | Health check |
| GET | `/api/v1/accounts/{id}/sync_accounts/info` | Service info |

## Testing

### Health Check
```bash
curl https://your-domain.com/api/v1/accounts/1/sync_accounts/health
```

### Test with Sample Data
```bash
# Run comprehensive test suite
ruby custom/scripts/testing/test_sync_accounts.rb

# Test against your Azure deployment
ruby custom/scripts/testing/test_sync_accounts.rb https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io
```

### Manual API Test
```bash
curl -X POST \
  https://your-domain.com/api/v1/accounts/1/sync_accounts/sync \
  -H "Content-Type: application/json" \
  -d '{
    "sync_accounts": {
      "sm_store_id": "test_store_001",
      "store_name": "My Test Store",
      "chatwoot_account_id": 1,
      "users": [
        {
          "sm_user_id": "user_001",
          "name": "Test User",
          "chatwoot_user_id": null
        }
      ]
    }
  }'
```

## Service Features

### ✅ Implemented
- User creation with auto-generated emails
- User updates and name changes
- Automatic user reactivation
- Administrator role assignment
- Inbox membership management
- Comprehensive logging
- Error handling and validation
- Health monitoring endpoints

### ⚠️ Security Note
**Authentication is currently DISABLED for testing**

Before production use:
1. Enable authentication in controller
2. Add proper authorization checks
3. Implement rate limiting
4. Review error message disclosure

### 🔧 Customization Points

**Email Generation:**
```ruby
# In sync_accounts_service.rb line ~150
def construct_email(sm_user_id)
  "user_#{sm_user_id}@voicelinkai.com"  # Customize this
end
```

**Inbox Selection:**
```ruby
# In sync_accounts_service.rb line ~220
inboxes = account.inboxes.where(channel_type: ['Channel::WebWidget', 'Channel::Api', 'Channel::TwilioSms'])
```

## Integration Examples

### External System Integration
```php
// PHP example
$data = [
    'sync_accounts' => [
        'sm_store_id' => $store_id,
        'store_name' => $store_name,
        'chatwoot_account_id' => $chatwoot_account_id,
        'users' => $users_array
    ]
];

$response = wp_remote_post($chatwoot_url . '/api/v1/accounts/' . $account_id . '/sync_accounts/sync', [
    'headers' => ['Content-Type' => 'application/json'],
    'body' => json_encode($data)
]);
```

### JavaScript Integration
```javascript
const syncUsers = async (storeData) => {
  const response = await fetch(`/api/v1/accounts/${accountId}/sync_accounts/sync`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ sync_accounts: storeData })
  });
  
  return await response.json();
};
```

## Monitoring

### Logs Location
- **Service logs:** `custom/logs/sync_accounts_service.log`
- **Rails logs:** Check Rails logger for errors
- **Request logs:** Standard Rails request logs

### Health Monitoring
```bash
# Add to cron for regular health checks
*/5 * * * * curl -f https://your-domain.com/api/v1/accounts/1/sync_accounts/health
```

## Next Steps

1. **Test thoroughly** with your data
2. **Enable authentication** for production
3. **Configure monitoring** and alerting
4. **Document integration** for your external systems
5. **Set up regular health checks**

## Support

- **Full API docs:** `custom/documentation/api/sync_accounts_api.md`
- **Service code:** `custom/services/sync_accounts_service.rb`
- **Test script:** `custom/scripts/testing/test_sync_accounts.rb` 