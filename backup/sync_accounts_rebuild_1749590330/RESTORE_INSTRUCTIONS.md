# SyncAccounts Implementation Restoration Guide
**Created:** 2025-06-10 21:25:30  
**Purpose:** Restore complete SyncAccounts implementation after container rebuild

## Files to Restore

### 1. Rails Application Files (Critical)
```bash
# Main API Controller
cp controllers/sync_accounts_controller.rb app/controllers/api/v1/accounts/

# Business Logic Service  
cp services/sync_accounts_service.rb lib/services/

# Logging Utility
cp utilities/logger.rb lib/utilities/

# Routes Configuration (MERGE - don't overwrite!)
# Manually merge routes/routes.rb changes into config/routes.rb
# Look for lines 159-167 with sync_accounts routes
```

### 2. Routes Configuration Changes
Add these lines to `config/routes.rb` inside the accounts scope (around line 159):
```ruby
# Custom SyncAccounts service routes  
# 2025-06-10 13:20:00 - Added SyncAccounts API for external system integration
resources :sync_accounts, only: [:index, :create] do
  collection do
    get :health
  end
end
```

### 3. API Endpoints After Restoration
```
GET  /api/v1/accounts/{id}/sync_accounts        - Service info & documentation
POST /api/v1/accounts/{id}/sync_accounts        - Sync users between systems  
GET  /api/v1/accounts/{id}/sync_accounts/health - Health check
```

## Key Features Implemented
- **Multi-stage User Lookup:** chatwoot_user_id → username → email → create new
- **Smart ID Correction:** Returns correct chatwoot_user_id when external system has wrong ID
- **Username-based Search:** Finds users by username within account scope
- **Changed Flag Tracking:** Marks users that were corrected or modified
- **Enhanced Error Handling:** Comprehensive error responses and logging

## Testing After Restoration
```bash
# Run comprehensive test suite
ruby custom/scripts/testing/test_sync_accounts_advanced.rb [BASE_URL]

# Quick health check
curl "https://[DOMAIN]/api/v1/accounts/1/sync_accounts/health"

# Service info
curl "https://[DOMAIN]/api/v1/accounts/1/sync_accounts"
```

## JSON Input/Output Format
### Input:
```json
{
  "sync_accounts": {
    "sm_store_id": "store_123",
    "store_name": "Store Name", 
    "chatwoot_account_id": 1,
    "users": [{
      "sm_user_id": "user_001",
      "name": "John Doe",
      "username": "john.doe",
      "chatwoot_user_id": 25  // Optional, can be null/wrong
    }]
  }
}
```

### Output:
```json
{
  "success": true,
  "data": {
    "users": [{
      "sm_user_id": "user_001",
      "name": "John Doe", 
      "username": "john.doe",
      "chatwoot_user_id": 25,  // Corrected if needed
      "changed_flag": true     // True if ID was corrected
    }],
    "summary": {
      "total_users": 1,
      "changed_users": 1,
      "errors": 0
    }
  }
}
```

## Verification Steps
1. ✅ Files copied to correct Rails locations
2. ✅ Routes added to config/routes.rb  
3. ✅ Container restarted/rebuilt
4. ✅ Health endpoint returns JSON (not 404)
5. ✅ Advanced test suite passes all scenarios

## Troubleshooting
If routes still return 404 after restoration:
1. Verify controller inheritance: `Api::V1::Accounts::BaseController`
2. Check file permissions and locations
3. Restart Rails application
4. Review debug file: `debug/sync_accounts_routing_issue_20250610.md` 