#!/usr/bin/env ruby

# Custom Integration Health Check
# Created: 2025-06-10 08:43:00 PDT
# Purpose: Monitor health of custom integrations and services

require 'net/http'
require 'json'
require 'uri'

class CustomHealthChecker
  def initialize
    @results = []
    @api_token = ENV['PLATFORM_API_TOKEN'] || 'YkT9vdgc2UFZ2kgMhPdEaajT'
    @base_url = ENV['CHATWOOT_API_BASE_URL'] || 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
  end

  def run_health_checks
    puts "🏥 Custom Integration Health Check"
    puts "📅 #{Time.now}"
    puts "=" * 50

    check_platform_api
    check_twilio_endpoints
    check_custom_services
    check_account_health
    
    puts "=" * 50
    puts "📊 Health Check Summary:"
    
    passed = @results.count { |r| r[:status] == 'PASS' }
    failed = @results.count { |r| r[:status] == 'FAIL' }
    
    puts "✅ Passed: #{passed}"
    puts "❌ Failed: #{failed}"
    
    if failed > 0
      puts "\n🚨 Failed Checks:"
      @results.select { |r| r[:status] == 'FAIL' }.each do |result|
        puts "  - #{result[:name]}: #{result[:error]}"
      end
      exit 1
    else
      puts "\n🎉 All health checks passed!"
      exit 0
    end
  end

  private

  def check_platform_api
    check_name = "Platform API Connection"
    print "Checking #{check_name}... "

    begin
      uri = URI("#{@base_url}/platform/api/v1/accounts")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 10

      request = Net::HTTP::Get.new(uri)
      request['api_access_token'] = @api_token

      response = http.request(request)
      
      if response.code.to_i == 200
        accounts = JSON.parse(response.body)
        puts "✅ PASS (#{accounts.size} accounts)"
        @results << { name: check_name, status: 'PASS', details: "#{accounts.size} accounts found" }
      else
        puts "❌ FAIL (HTTP #{response.code})"
        @results << { name: check_name, status: 'FAIL', error: "HTTP #{response.code}: #{response.body}" }
      end
    rescue => e
      puts "❌ FAIL (#{e.class}: #{e.message})"
      @results << { name: check_name, status: 'FAIL', error: "#{e.class}: #{e.message}" }
    end
  end

  def check_twilio_endpoints
    endpoints = [
      { name: 'Twilio Webhook', url: 'https://voicelinkai.com/twilio/callback', method: 'HEAD' },
      { name: 'Domain Resolution', url: 'https://voicelinkai.com', method: 'HEAD' }
    ]

    endpoints.each do |endpoint|
      check_name = endpoint[:name]
      print "Checking #{check_name}... "

      begin
        uri = URI(endpoint[:url])
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 10

        request = case endpoint[:method]
                  when 'HEAD'
                    Net::HTTP::Head.new(uri)
                  else
                    Net::HTTP::Get.new(uri)
                  end

        response = http.request(request)
        
        # Accept 200, 404, 405 as valid responses (endpoint exists)
        if [200, 404, 405].include?(response.code.to_i)
          puts "✅ PASS (HTTP #{response.code})"
          @results << { name: check_name, status: 'PASS', details: "HTTP #{response.code}" }
        else
          puts "❌ FAIL (HTTP #{response.code})"
          @results << { name: check_name, status: 'FAIL', error: "HTTP #{response.code}" }
        end
      rescue => e
        puts "❌ FAIL (#{e.class}: #{e.message})"
        @results << { name: check_name, status: 'FAIL', error: "#{e.class}: #{e.message}" }
      end
    end
  end

  def check_custom_services
    check_name = "Custom Account Service"
    print "Checking #{check_name}... "

    begin
      # Test if our custom service can be loaded
      service_file = File.join(File.dirname(__FILE__), '../../lib/services/enhanced_account_service.rb')
      
      if File.exist?(service_file)
        # Try to load and instantiate the service
        require_relative '../../lib/utilities/logger'
        require_relative '../../lib/services/enhanced_account_service'
        
        service = EnhancedAccountService.new(@api_token)
        stats = service.get_account_statistics
        
        if stats && stats[:total_accounts]
          puts "✅ PASS (#{stats[:total_accounts]} accounts, #{stats[:duplicate_count]} duplicates)"
          @results << { name: check_name, status: 'PASS', details: "Service functional with #{stats[:total_accounts]} accounts" }
        else
          puts "❌ FAIL (No statistics returned)"
          @results << { name: check_name, status: 'FAIL', error: "Service returned no statistics" }
        end
      else
        puts "❌ FAIL (Service file not found)"
        @results << { name: check_name, status: 'FAIL', error: "Service file not found at #{service_file}" }
      end
    rescue => e
      puts "❌ FAIL (#{e.class}: #{e.message})"
      @results << { name: check_name, status: 'FAIL', error: "#{e.class}: #{e.message}" }
    end
  end

  def check_account_health
    check_name = "Account Data Integrity"
    print "Checking #{check_name}... "

    begin
      uri = URI("#{@base_url}/platform/api/v1/accounts")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Get.new(uri)
      request['api_access_token'] = @api_token

      response = http.request(request)
      
      if response.code.to_i == 200
        accounts = JSON.parse(response.body)
        
        # Check for data integrity issues
        issues = []
        
        # Check for accounts without names
        no_name = accounts.count { |acc| acc['name'].nil? || acc['name'].strip.empty? }
        issues << "#{no_name} accounts without names" if no_name > 0
        
        # Check for duplicate names
        names = accounts.map { |acc| acc['name'] }.compact
        duplicates = names.size - names.uniq.size
        issues << "#{duplicates} duplicate names" if duplicates > 0
        
        # Check for timestamp-based names (likely test data)
        timestamp_names = accounts.count { |acc| acc['name'] && acc['name'].match?(/\d{10,}/) }
        issues << "#{timestamp_names} timestamp-based names" if timestamp_names > 0

        if issues.empty?
          puts "✅ PASS (#{accounts.size} accounts, no issues)"
          @results << { name: check_name, status: 'PASS', details: "#{accounts.size} accounts with no integrity issues" }
        else
          puts "⚠️  WARN (#{issues.join(', ')})"
          @results << { name: check_name, status: 'PASS', details: "Issues found: #{issues.join(', ')}" }
        end
      else
        puts "❌ FAIL (HTTP #{response.code})"
        @results << { name: check_name, status: 'FAIL', error: "HTTP #{response.code}: #{response.body}" }
      end
    rescue => e
      puts "❌ FAIL (#{e.class}: #{e.message})"
      @results << { name: check_name, status: 'FAIL', error: "#{e.class}: #{e.message}" }
    end
  end
end

# Run health checks if script is executed directly
if __FILE__ == $0
  checker = CustomHealthChecker.new
  checker.run_health_checks
end 