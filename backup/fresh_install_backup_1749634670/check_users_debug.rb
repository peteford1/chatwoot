#!/usr/bin/env ruby

puts "=== COMPLETE USER AUDIT ==="
puts "Total users in database: #{User.unscoped.count}"

puts "\n=== ALL USERS BY ID ==="
User.unscoped.order(:id).each_with_index do |u, i|
  user_type = u.type || "User"
  puts "#{i+1}. ID: #{u.id} | Name: #{u.name} | Email: #{u.email} | Type: #{user_type} | Confirmed: #{u.confirmed?}"
end

puts "\n=== ACTIVE ACCOUNTS ==="
Account.where(status: :active).each do |a|
  puts "ID: #{a.id} | Name: #{a.name} | Status: #{a.status}"
end

puts "\n=== ACCOUNT USER RELATIONSHIPS ==="
AccountUser.joins(:user, :account).each do |au|
  puts "Account: #{au.account.name} (#{au.account_id}) | User: #{au.user.name} (#{au.user_id}) | Role: #{au.role}"
end

puts "\n=== UI VISIBILITY CHECK ==="
puts "Confirmed users that should show in UI: #{User.confirmed.count}"
puts "SuperAdmin users: #{User.where(type: 'SuperAdmin').count}"
puts "Regular users: #{User.where(type: [nil, 'User']).count}" 