# Check PlatformApp model attributes
puts "PlatformApp attributes:"
puts PlatformApp.attribute_names.inspect

puts "\nPlatformApp columns:"
PlatformApp.columns.each do |column|
  puts "  #{column.name}: #{column.type}"
end 