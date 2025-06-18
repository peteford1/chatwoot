# Example: How to use the Admin API Token in Custom Code
# This shows how your custom controllers/services can make API calls to Chatwoot

class CustomChatwootService
  def initialize
    @api_token = ENV['CHATWOOT_ADMIN_API_TOKEN']
    @base_url = ENV['FRONTEND_URL'] || 'https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io'
  end

  # Get user profile
  def get_admin_profile
    make_api_request('/api/v1/profile')
  end

  # Get all accounts (if any exist)
  def get_accounts
    make_api_request('/api/v1/accounts')
  end

  # Create a new account
  def create_account(name)
    make_api_request('/api/v1/accounts', method: :post, body: { name: name })
  end

  # Get users for an account
  def get_account_users(account_id)
    make_api_request("/api/v1/accounts/#{account_id}/users")
  end

  private

  def make_api_request(endpoint, method: :get, body: nil)
    require 'net/http'
    require 'json'
    require 'uri'

    uri = URI("#{@base_url}#{endpoint}")
    
    case method
    when :get
      request = Net::HTTP::Get.new(uri)
    when :post
      request = Net::HTTP::Post.new(uri)
      request.body = body.to_json if body
      request['Content-Type'] = 'application/json'
    when :put
      request = Net::HTTP::Put.new(uri)
      request.body = body.to_json if body
      request['Content-Type'] = 'application/json'
    when :delete
      request = Net::HTTP::Delete.new(uri)
    end

    # Add the API token header
    request['api_access_token'] = @api_token

    # Make the request
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
      http.request(request)
    end

    # Parse response
    case response.code.to_i
    when 200..299
      JSON.parse(response.body) if response.body && !response.body.empty?
    else
      Rails.logger.error "Chatwoot API Error: #{response.code} - #{response.body}"
      nil
    end
  rescue => e
    Rails.logger.error "Chatwoot API Exception: #{e.message}"
    nil
  end
end

# Usage examples:
# service = CustomChatwootService.new
# profile = service.get_admin_profile
# accounts = service.get_accounts
# new_account = service.create_account("My Company")

# In a controller:
class CustomController < ApplicationController
  def sync_users
    service = CustomChatwootService.new
    
    # Get current admin profile
    admin_profile = service.get_admin_profile
    
    if admin_profile
      render json: { 
        status: 'success', 
        admin: admin_profile,
        message: 'Successfully connected to Chatwoot API'
      }
    else
      render json: { 
        status: 'error', 
        message: 'Failed to connect to Chatwoot API'
      }, status: 500
    end
  end
end 