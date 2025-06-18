# Create platform app with just the name
platform_app = PlatformApp.create!(name: 'Storefront Platform App')
puts '✅ Created platform app: ' + platform_app.name

puts ''
puts '━' * 60
puts '🔑 STOREFRONT PLATFORM TOKEN:'
puts platform_app.access_token
puts '━' * 60
puts ''
puts '🎯 READY FOR TESTING!'
puts 'Account ID: 1'
puts 'User Email: storeadmin@voicelinkai.com'
puts 'Platform Token: ' + platform_app.access_token
puts ''
puts '📋 Storefront Environment Variables:'
puts 'CHATWOOT_API_URL=https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
puts 'CHATWOOT_PLATFORM_TOKEN=' + platform_app.access_token
puts 'CHATWOOT_ACCOUNT_ID=1'
puts ''
puts '🧪 Test API Access:'
puts 'curl -H "api_access_token: ' + platform_app.access_token + '" https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/platform/api/v1/accounts' 