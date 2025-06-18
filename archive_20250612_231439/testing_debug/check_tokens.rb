#!/usr/bin/env ruby

puts "🔍 Checking existing Access Tokens in Production..."
puts

AccessToken.all.each do |token|
  puts "ID: #{token.id}"
  puts "Type: #{token.owner_type}"
  puts "Token: #{token.token}"
  puts "Owner ID: #{token.owner_id}"
  puts "Created: #{token.created_at}"
  
  if token.owner_type == 'PlatformApp'
    app = token.owner
    puts "App Name: #{app.name}"
    puts "Permissions: #{app.platform_app_permissibles.count} accounts"
    app.platform_app_permissibles.each do |perm|
      puts "  - #{perm.permissible.class}: #{perm.permissible.name} (ID: #{perm.permissible.id})"
    end
  elsif token.owner_type == 'User'
    user = token.owner
    puts "User: #{user.name} (#{user.email})"
  end
  
  puts "=" * 50
end

puts "Total tokens: #{AccessToken.count}" 