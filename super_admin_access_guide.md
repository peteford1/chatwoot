# Super Admin Access Guide for Token Generation

## 🔐 Accessing Super Admin Interface

### Step 1: Check if Super Admin Exists
Visit: `https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/super_admin/sign_in`

Try these common credentials:
- Email: `admin@voicelinkai.com` / Password: `SuperAdmin!`
- Email: `admin@chatwoot.local` / Password: `admin123`
- Email: `superadmin@chatwoot.local` / Password: `password`

### Step 2: Create Super Admin (if none exists)
If no super admin exists, you'll need database access to create one:

```sql
-- Connect to PostgreSQL database
INSERT INTO super_admins (email, encrypted_password, created_at, updated_at)
VALUES (
  'emergency@chatwoot.local',
  '$2a$11$' || encode(digest('EmergencyPass123!', 'sha256'), 'base64'),
  NOW(),
  NOW()
);
```

### Step 3: Generate Tokens via Super Admin Interface

Once logged into super admin:

#### Create Platform App Token:
1. Navigate to **Platform Apps** section
2. Click **New Platform App**
3. Enter name: "Emergency Platform App"
4. Save and copy the generated access token

#### Create User Token:
1. Navigate to **Users** section  
2. Find or create a user
3. Click on the user
4. Look for **Access Token** field
5. If no token exists, it will be auto-generated

## 🚨 Emergency Super Admin Creation Script

If you need to create a super admin via database:

```ruby
# Via Rails console (if accessible)
SuperAdmin.create!(
  email: 'emergency@chatwoot.local',
  password: 'EmergencyPass123!',
  password_confirmation: 'EmergencyPass123!'
)
```

```sql
-- Via direct SQL (if Rails console not accessible)
INSERT INTO super_admins (
  email, 
  encrypted_password, 
  created_at, 
  updated_at
) VALUES (
  'emergency@chatwoot.local',
  '$2a$11$YourBcryptHashHere',
  NOW(),
  NOW()
);
```

## 📋 Super Admin Capabilities

Once logged in as super admin, you can:

- ✅ View all platform apps and their tokens
- ✅ Create new platform apps (auto-generates tokens)
- ✅ View all users and their tokens  
- ✅ Create new users (auto-generates tokens)
- ✅ Manage accounts and permissions
- ✅ Access system-wide settings

## 🔗 Super Admin URLs

- Login: `/super_admin/sign_in`
- Dashboard: `/super_admin/`
- Platform Apps: `/super_admin/platform_apps`
- Users: `/super_admin/users`
- Access Tokens: `/super_admin/access_tokens`

## ⚠️ Security Notes

- Super admin has full system access
- Change default passwords immediately
- Use strong, unique passwords
- Consider enabling 2FA if available
- Log out after token generation 