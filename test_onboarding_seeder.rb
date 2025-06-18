#!/usr/bin/env ruby

puts "🧪 Testing VoiceLinkAI Onboarding Seeder"
puts "=" * 50

# Test the onboarding seeder
system("ruby scripts/deployment_seeder_onboarding.rb https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io")

puts "\n🔍 Checking generated files..."

# List any generated env files
env_files = Dir.glob("voicelinkai_deployment_*.env")
if env_files.any?
  puts "✅ Generated environment files:"
  env_files.each { |file| puts "   📄 #{file}" }
  
  # Show the latest file content
  latest_file = env_files.sort.last
  puts "\n📋 Latest configuration (#{latest_file}):"
  puts "-" * 30
  puts File.read(latest_file)
else
  puts "❌ No environment files generated"
end

puts "\n✨ Test completed!" 