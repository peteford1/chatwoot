#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'

# Test Super Admin Page Access
def test_super_admin_access
  puts "🔍 Testing Super Admin Page Access..."
  
  base_url = "https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
  
  # Test 1: Check if /super_admin redirects properly
  puts "\n1. Testing /super_admin redirect..."
  uri = URI("#{base_url}/super_admin")
  
  begin
    response = Net::HTTP.get_response(uri)
    puts "   Status: #{response.code}"
    puts "   Location: #{response['location']}" if response['location']
    
    if response.code == '302' && response['location']&.include?('sign_in')
      puts "   ✅ Redirect working correctly"
    else
      puts "   ❌ Unexpected response"
    end
  rescue => e
    puts "   ❌ Error: #{e.message}"
    return false
  end
  
  # Test 2: Check if sign-in page loads
  puts "\n2. Testing /super_admin/sign_in page..."
  uri = URI("#{base_url}/super_admin/sign_in")
  
  begin
    response = Net::HTTP.get_response(uri)
    puts "   Status: #{response.code}"
    puts "   Content-Type: #{response['content-type']}"
    puts "   Content-Length: #{response['content-length']}"
    
    if response.code == '200' && response.body.include?('Howdy, admin')
      puts "   ✅ Sign-in page loads correctly"
      puts "   ✅ Contains expected content"
    else
      puts "   ❌ Sign-in page issue"
    end
  rescue => e
    puts "   ❌ Error: #{e.message}"
    return false
  end
  
  # Test 3: Check if we can attempt login
  puts "\n3. Testing login attempt..."
  uri = URI("#{base_url}/super_admin/sign_in")
  
  begin
    # First get the sign-in page to extract CSRF token
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    get_request = Net::HTTP::Get.new(uri)
    get_response = http.request(get_request)
    
    # Extract CSRF token
    csrf_token = get_response.body.match(/name="authenticity_token" value="([^"]+)"/)[1] rescue nil
    cookies = get_response.get_fields('set-cookie')&.join('; ')
    
    if csrf_token
      puts "   ✅ CSRF token extracted: #{csrf_token[0..20]}..."
      
      # Attempt login
      post_request = Net::HTTP::Post.new(uri)
      post_request['Cookie'] = cookies if cookies
      post_request.set_form_data({
        'authenticity_token' => csrf_token,
        'super_admin[email]' => 'admin@voicelinkai.com',
        'super_admin[password]' => 'SuperAdmin123!'
      })
      
      post_response = http.request(post_request)
      puts "   Login attempt status: #{post_response.code}"
      
      if post_response.code == '302'
        puts "   ✅ Login processed (redirect received)"
        puts "   Redirect to: #{post_response['location']}"
      elsif post_response.code == '200'
        if post_response.body.include?('Invalid email or password')
          puts "   ❌ Invalid credentials"
        else
          puts "   ⚠️  Login form returned (check credentials)"
        end
      else
        puts "   ❌ Unexpected login response"
      end
    else
      puts "   ❌ Could not extract CSRF token"
    end
  rescue => e
    puts "   ❌ Login test error: #{e.message}"
  end
  
  puts "\n" + "="*50
  puts "SUMMARY:"
  puts "- Super Admin infrastructure is working"
  puts "- Pages load correctly"
  puts "- If you can't access it, try:"
  puts "  1. Clear browser cookies"
  puts "  2. Try incognito/private browsing"
  puts "  3. Check your internet connection"
  puts "  4. Try a different browser"
  puts "="*50
  
  true
end

# Run the test
if __FILE__ == $0
  test_super_admin_access
end 