# Database Reset Operation - $(date)

## ⚠️ DESTRUCTIVE OPERATION WARNING

This operation will completely wipe all Chatwoot data including:

### 🗑️ Data to be deleted:
- **All Accounts** (Acme Inc, Acme Org, and any others)
- **All Users** (John, Demo User, Super Admin, etc.)
- **All Inboxes** (Twilio SMS Test, Web Widget, etc.)
- **All Conversations** and **Messages**
- **All Contacts** and **Contact Inboxes**
- **All Channels** (Twilio, Email, Web Widget, etc.)
- **All Teams**, **Labels**, **Custom Attributes**
- **All Access Tokens** and **Account relationships**

### 📋 Previous Configuration (to be lost):

**Account 1: Acme Inc**
- Twilio SMS Inbox with phone +19795412927
- Account SID: AC62c0b1130dca59524440547d60dd10a9
- Web Widget Inbox: "Acme Support"

**Account 2: Acme Org**
- Secondary account

**Users:**
- John (john@acme.inc) - Administrator
- Demo User (demo@test.com) - Agent  
- Super Admin (admin@voicelinkai.com) - Global Super Admin

### 🔧 Post-Reset Setup Required:

1. **Create new Super Admin account** via onboarding flow
2. **Recreate Twilio SMS integration** with:
   - Phone: +19795412927
   - Account SID: AC62c0b1130dca59524440547d60dd10a9
   - Webhook URL: https://voicelinkai.com/twilio/callback

3. **Recreate user accounts** and assign proper roles
4. **Reconfigure KrakenD endpoints** if needed for new account IDs
5. **Test webhook integrations** after setup

### 🎯 Reason for Reset:
User requested a fresh start to clean up all existing accounts, users, and inboxes.

### ⚡ Execution:
```bash
bundle exec ruby temp_console_fix.rb
```

**Confirmation required:** Type 'DELETE ALL DATA' when prompted.

---
**Created:** $(date)  
**Status:** Pending execution 