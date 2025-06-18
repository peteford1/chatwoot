# Chatwoot SMS Configuration Guide

## Current Configuration Status ✅

Your Chatwoot instance is **already configured** for SMS sending through Twilio:

### Twilio Channel Configuration
- **Channel ID**: 1
- **Phone Number**: +19795412927
- **Account SID**: ACtest123456789 ✅
- **Auth Token**: SET ✅
- **Inbox Name**: Twilio SMS Test
- **Account**: Acme Inc

### Demo User Access
- **Email**: demo@test.com
- **Password**: Password123!
- **Account**: Acme Inc (ID: 1)
- **Access to Twilio Inbox**: ✅ (Inbox ID: 2)

### Available Conversations
- **Conversation ID**: 2
- **Contact**: +1 435-339-7687 (+14353397687)
- **Status**: Open
- **Assigned to**: Demo User
- **Inbox**: Twilio SMS Test

## How to Send SMS Messages

### Method 1: Through Chatwoot Dashboard
1. Login to your Chatwoot dashboard at: 
   `https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io`
2. Use credentials: `demo@test.com` / `Password123!`
3. Navigate to the "Twilio SMS Test" inbox
4. Open the conversation with contact "+1 435-339-7687"
5. Type your message and press Send

### Method 2: Through API
```bash
# Send SMS via API (replace YOUR_API_TOKEN)
curl -X POST \
  https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/accounts/1/conversations/2/messages \
  -H "api_access_token: YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Hello! This is a test SMS message.",
    "message_type": "outgoing"
  }'
```

### Method 3: Direct Rails Console
```ruby
# From Rails console
conversation = Conversation.find(2)
user = User.find_by(email: 'demo@test.com')

message = Message.create!(
  content: "Hello from Chatwoot!",
  message_type: 'outgoing',
  inbox: conversation.inbox,
  account: conversation.account,
  conversation: conversation,
  sender: user
)
```

## Testing SMS Reception

To test receiving SMS messages, send a text to **+19795412927** and it will appear in the conversation.

## Webhook Configuration

Your webhooks are configured at:
- **Incoming**: `/twilio/callback`
- **Delivery Status**: `/twilio/delivery_status`

## Troubleshooting

### Common Issues:
1. **Message Status "failed"**: Check Twilio credentials and phone number verification
2. **API Token**: Generate from Settings > Integrations > API Access Tokens
3. **Phone Number Format**: Ensure numbers are in E.164 format (+1XXXXXXXXXX)

### Debug Commands:
```bash
# Check Twilio configuration
bundle exec rails runner "Channel::TwilioSms.first.inspect"

# Check conversations
bundle exec rails runner "Conversation.where(inbox_id: 2).inspect"

# Check recent messages
bundle exec rails runner "Message.where(conversation_id: 2).order(:created_at).last(5).inspect"
```

## Next Steps

1. **Test sending a message** through the dashboard
2. **Create additional contacts** for different phone numbers
3. **Set up automation rules** for SMS responses
4. **Configure agent notifications** for incoming SMS

---

**Configuration completed!** Your SMS system is ready for use. 