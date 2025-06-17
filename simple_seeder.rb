puts "=== VoiceLinkAI Test Environment Seeder ==="
puts "Environment: #{Rails.env rescue 'Unknown'}"
puts "Creating Platform App..."

begin
  platform_app = PlatformApp.create!(name: 'VoiceLinkAI Test Platform')
  puts "Platform App Created: ID #{platform_app.id}"
  puts "Access Token: #{platform_app.access_token.token[0..20]}..."
  
  puts "Creating Account..."
  account = Account.create!(name: 'voicelinkai', locale: 'en')
  puts "Account Created: ID #{account.id}"
  
  puts "Creating Admin User..."
  user = User.create!(
    name: 'VoiceLinkAI Admin',
    email: 'admin@voicelinkai.com',
    password: '123@321Qq',
    confirmed_at: Time.current
  )
  puts "User Created: ID #{user.id}"
  puts "User Token: #{user.access_token.token[0..20]}..."
  
  puts "Linking User to Account..."
  account_user = AccountUser.create!(
    account: account,
    user: user,
    role: 'administrator'
  )
  puts "Account User Created: ID #{account_user.id}"
  
  puts "\n=== SUCCESS ==="
  puts "Platform Token: #{platform_app.access_token.token}"
  puts "Admin Token: #{user.access_token.token}"
  puts "Account ID: #{account.id}"
  puts "User ID: #{user.id}"
  
rescue => e
  puts "ERROR: #{e.message}"
  puts e.backtrace.first(3)
end 