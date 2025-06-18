#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'openssl'

puts "🌐 Testing Super Admin Panel Routes..."

# URLs to test
urls = [
  'https://voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io/super_admin',
  'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/super_admin'
]

urls.each_with_index do |url, index|
  puts "\n#{index + 1}. Testing: #{url}"
  
  begin
    uri = URI(url)
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.read_timeout = 10
    http.open_timeout = 10
    
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = 'SuperAdmin Route Test'
    
    response = http.request(request)
    
    puts "   Status: #{response.code} #{response.message}"
    
    case response.code.to_i
    when 200
      puts "   ✅ SUCCESS: Super admin panel is accessible!"
      puts "   Response includes login form: #{response.body.include?('super_admin') ? 'Yes' : 'No'}"
      puts "   Response includes 'email': #{response.body.include?('email') ? 'Yes' : 'No'}"
      puts "   Response includes 'password': #{response.body.include?('password') ? 'Yes' : 'No'}"
      
    when 302, 301
      puts "   🔄 REDIRECT: #{response['Location']}"
      puts "   This might be normal - redirecting to login"
      
    when 404
      puts "   ❌ NOT FOUND: Super admin routes not configured or not accessible"
      puts "   Possible issues:"
      puts "     - Routes not properly defined"
      puts "     - Application not running"
      puts "     - Wrong URL path"
      
    when 500
      puts "   💥 SERVER ERROR: Application error"
      puts "   Check application logs for details"
      
    when 403
      puts "   🚫 FORBIDDEN: Access denied"
      puts "   Routes exist but access is restricted"
      
    else
      puts "   ⚠️  UNEXPECTED: #{response.code}"
      puts "   Response body preview: #{response.body[0..200]}..."
    end
    
    # Check response headers for clues
    if response['Server']
      puts "   Server: #{response['Server']}"
    end
    
    if response['X-Powered-By']
      puts "   Powered by: #{response['X-Powered-By']}"
    end
    
  rescue Net::TimeoutError
    puts "   ⏰ TIMEOUT: Request timed out"
    puts "   Server might be slow or unreachable"
    
  rescue Net::ConnectTimeout
    puts "   🔌 CONNECTION TIMEOUT: Cannot connect to server"
    puts "   Server might be down or URL incorrect"
    
  rescue SocketError => e
    puts "   🌐 DNS ERROR: #{e.message}"
    puts "   Check if the hostname is correct"
    
  rescue => e
    puts "   💥 ERROR: #{e.class} - #{e.message}"
  end
end

puts "\n📋 Summary:"
puts "   If you see 404 errors, the super admin routes are not working"
puts "   If you see 200 or redirects, the routes work but you need login credentials"
puts "   For login, use: admin@voicelinkai.com with the correct password"

puts "\n💡 Next steps if routes are working:"
puts "   1. Try logging in with admin@voicelinkai.com"
puts "   2. If password is forgotten, reset it via Rails console"
puts "   3. If account is not confirmed, confirm it via Rails console"

puts "\n✨ Route testing completed!" 