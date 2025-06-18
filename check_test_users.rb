puts "Users in database:"
User.all.each do |u| 
  token = u.access_token&.token || "None"
  puts "- #{u.email} (ID: #{u.id}, Type: #{u.type}, Token: #{token})"
end 