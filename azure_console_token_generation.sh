#!/bin/bash

echo "🚨 EMERGENCY TOKEN GENERATION - AZURE CONTAINER CONSOLE"
echo "============================================================"

# Azure Container App details
RESOURCE_GROUP="SM-Test"
CONTAINER_APP="chatwoot-backend-test"

echo "📋 Connecting to Azure Container App console..."
echo "Resource Group: $RESOURCE_GROUP"
echo "Container App: $CONTAINER_APP"

# Check if Azure CLI is logged in
if ! az account show &>/dev/null; then
    echo "❌ Not logged into Azure CLI. Please run: az login"
    exit 1
fi

echo "✅ Azure CLI authenticated"

# Create Rails console commands
RAILS_COMMANDS=$(cat << 'EOF'
puts "🚨 EMERGENCY TOKEN GENERATION VIA RAILS CONSOLE"
puts "=" * 50

# Create emergency admin user
unique_id = SecureRandom.hex(4)
email = "emergency_admin_#{unique_id}@chatwoot.local"

user = User.create!(
  name: "Emergency Admin",
  email: email,
  password: "EmergencyPass123!",
  confirmed_at: Time.current
)

puts "✅ Created emergency user: #{user.email} (ID: #{user.id})"

# Add to first account as administrator
account = Account.first
if account.nil?
  puts "❌ No accounts found"
  exit
end

account_user = AccountUser.create!(
  account: account,
  user: user,
  role: 'administrator'
)

puts "✅ Added user to account: #{account.name} (ID: #{account.id})"

# Create API token for user
user_token = user.access_token.token
puts "✅ User API Token: #{user_token}"

# Create platform app and token
platform_app = PlatformApp.create!(
  name: "Emergency Platform App - #{Time.current.strftime('%Y%m%d_%H%M%S')}"
)

# Add permissions for the account
PlatformAppPermissible.create!(
  platform_app: platform_app,
  permissible: account
)

platform_token = platform_app.access_token.token
puts "✅ Platform Token: #{platform_token}"

puts "\n" + "=" * 60
puts "🎉 EMERGENCY TOKENS CREATED!"
puts "=" * 60
puts "User Email: #{email}"
puts "User Token: #{user_token}"
puts "Platform Token: #{platform_token}"
puts "=" * 60

puts "\n💾 SAVE THESE TOKENS:"
puts "export CHATWOOT_USER_TOKEN='#{user_token}'"
puts "export CHATWOOT_PLATFORM_TOKEN='#{platform_token}'"
EOF
)

# Write Rails commands to temporary file
TEMP_FILE="/tmp/emergency_tokens_$(date +%s).rb"
echo "$RAILS_COMMANDS" > "$TEMP_FILE"

echo "📝 Created Rails script: $TEMP_FILE"

# Execute via Azure Container App
echo "🚀 Executing Rails console commands..."
echo "⏳ This may take a few minutes..."

# Method 1: Try direct Rails console execution
echo "🔄 Attempting Method 1: Direct Rails console..."
az containerapp exec \
  --name "$CONTAINER_APP" \
  --resource-group "$RESOURCE_GROUP" \
  --command "bash -c 'cd /app && bundle exec rails runner \"$(cat $TEMP_FILE)\"'" \
  2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Method 1 succeeded!"
else
    echo "❌ Method 1 failed, trying Method 2..."
    
    # Method 2: Interactive console session
    echo "🔄 Attempting Method 2: Interactive console..."
    echo "📋 You'll need to paste the following commands manually:"
    echo "----------------------------------------"
    cat "$TEMP_FILE"
    echo "----------------------------------------"
    
    echo "🚀 Opening interactive Rails console..."
    az containerapp exec \
      --name "$CONTAINER_APP" \
      --resource-group "$RESOURCE_GROUP" \
      --command "bash -c 'cd /app && bundle exec rails console'"
fi

# Cleanup
rm -f "$TEMP_FILE"
echo "🧹 Cleaned up temporary files" 