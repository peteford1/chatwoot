# Check PlatformApp model structure
puts "PlatformApp attributes:"
puts PlatformApp.attribute_names.inspect

puts "\nPlatformApp columns:"
PlatformApp.columns.each do |column|
  puts "  #{column.name}: #{column.type}"
end

puts "\nPlatformApp associations:"
PlatformApp.reflect_on_all_associations.each do |assoc|
  puts "  #{assoc.name}: #{assoc.macro} (#{assoc.class_name})"
end 