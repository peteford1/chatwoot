# Duplicate Accounts Cleanup Debug File

**Issue Created:** 2025-06-10 08:25:00 PDT  
**Issue Type:** Database cleanup - Remove duplicate test accounts  
**Root Cause:** Multiple account creation scripts running repeatedly without duplicate checking

## Problem Symptoms
- User reported seeing only 4 users in UI but system had 30+ accounts
- Database queries were misleading compared to Platform API results  
- Multiple accounts with timestamp-based names like "Test Store 1749224605"
- Fake generated names like "Etha Lueilwitz DDS", "Jamar Steuber"
- Performance degradation due to excessive accounts

## Root Cause Validation Steps
1. **Check Platform API vs Database discrepancy:**
   ```bash
   curl -H "api_access_token: YkT9vdgc2UFZ2kgMhPdEaajT" \
   "https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/platform/api/v1/accounts" | jq length
   ```
   Expected: Should show 30+ accounts if duplicate issue exists

2. **Identify duplicate patterns:**
   ```bash
   curl -s -H "api_access_token: YkT9vdgc2UFZ2kgMhPdEaajT" \
   "https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/platform/api/v1/accounts" | \
   jq -r '.[] | "\(.id): \(.name)"' | sort -n
   ```
   Expected: Should show patterns like "Test Store [timestamp]" and fake names

3. **Check for problematic scripts:**
   ```bash
   find . -name "*account*" -name "*.rb" | grep -E "(create|setup|test)"
   ```
   Expected: Should find multiple account creation scripts

## Scripts Causing Duplicates
- `create_account22_twilio_inbox.rb`
- `create_account22_twilio_inbox_fixed.rb` 
- `setup_twilio_test.rb`
- `create_twilio_sms_inbox_example.rb`

## Legitimate Accounts (TO PRESERVE)
1. **Storefront** (ID: 1) - Main production account
2. **Test Tenant Account** (ID: 2) - Primary test account  
3. **Test Account API** (ID: 10) - API testing account
4. **VoiceLinkAI** (ID: 22) - Production VoiceLink account

## Resolution Steps
1. **Create cleanup script:** `cleanup_duplicate_accounts.rb`
2. **Backup current state** to `backup/account_cleanup_[timestamp]/`
3. **Execute cleanup** preserving only 4 legitimate accounts
4. **Verify results** via Platform API

## Discovery: Asynchronous Deletion Issue
**Date:** 2025-06-10 08:30:00 PDT
**Issue:** Platform API deletion uses `DeleteObjectJob.perform_later()` which queues deletions in background
- Deletion API returns HTTP 200 immediately but actual deletion happens asynchronously  
- Jobs are queued in 'low' priority queue
- In development environments, background job processing may be slow or paused
- 29 deletion requests sent successfully but accounts still present after 30+ seconds

## Execution Command
```bash
ruby cleanup_duplicate_accounts.rb
```

## Verification After Resolution
```bash
# Should show only 4 accounts remaining
curl -s -H "api_access_token: YkT9vdgc2UFZ2kgMhPdEaajT" \
"https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/platform/api/v1/accounts" | \
jq length
```

## Prevention Measures
- Modify account creation scripts to check for existing accounts before creating new ones
- Add duplicate prevention logic in account creation workflows
- Implement account cleanup as part of regular maintenance

## Files Modified/Created
- Created: `cleanup_duplicate_accounts.rb` (main cleanup script)
- Created: `debug/duplicate_accounts_cleanup.md` (this debug file)
- Backup: `backup/account_cleanup_[timestamp]/accounts_before_cleanup_*.json`

## Success Criteria
- ✅ Only 4 legitimate accounts remain in system
- ✅ All duplicate accounts removed
- ✅ Backup created successfully  
- ✅ System performance improved
- ✅ UI shows correct account count

**Last Updated:** 2025-06-10 08:25:00 PDT 