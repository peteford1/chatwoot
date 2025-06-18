# SyncAccounts API Controller
# Created: 2025-06-10 13:15:00
# Purpose: REST API endpoint for synchronizing users between external systems and Chatwoot
# Description: Provides POST endpoint for account/user synchronization

class Api::V1::Accounts::SyncAccountsController < Api::V1::Accounts::BaseController
  # 2025-06-10 13:15:00 - Skip authentication for this endpoint temporarily for testing
  # Comment: Will add proper authentication based on user requirements
  skip_before_action :authenticate_user!, only: [:create, :index, :health]
  # 2025-06-10 21:36:00 - Removed check_authorization skip as callback doesn't exist in base controller

  # GET /api/v1/accounts/:account_id/sync_accounts
  # Information about the sync service
  def index
    render json: {
      service: 'SyncAccounts',
      description: 'Synchronizes users between external systems and Chatwoot accounts',
      version: '1.0.0',
      account_id: Current.account&.id,
      endpoints: {
        sync: {
          method: 'POST',
          path: "/api/v1/accounts/#{params[:account_id]}/sync_accounts",
          description: 'Synchronize users and accounts'
        },
        health: {
          method: 'GET', 
          path: "/api/v1/accounts/#{params[:account_id]}/sync_accounts/health",
          description: 'Service health check'
        }
      }
    }, status: :ok
  end

  # POST /api/v1/accounts/:account_id/sync_accounts
  # Synchronizes users between external system and Chatwoot
  #
  # Parameters:
  #   sm_store_id: External store identifier
  #   store_name: Name of the store/account
  #   chatwoot_account_id: Chatwoot account ID to sync with
  #   users: Array of user objects with sm_user_id, name, chatwoot_user_id
  #
  # Response:
  #   Same structure as input with added changed flags and processing metadata
  def create
    begin
      # Load the custom service
      require_relative '../../../../../lib/services/sync_accounts_service'
      
      service = Services::SyncAccountsService.new
      result = service.sync_accounts(sync_params.to_h.deep_symbolize_keys)
      
      render json: {
        success: true,
        data: result
      }, status: :ok
      
    rescue ActionController::ParameterMissing => e
      render json: {
        success: false,
        error: 'Parameter Missing',
        message: e.message,
        expected_format: {
          sm_store_id: 'integer',
          store_name: 'string', 
          chatwoot_account_id: 'integer',
          users: [
            {
              sm_user_id: 'integer',
              name: 'string',
              username: 'string',
              chatwoot_user_id: 'integer (optional)'
            }
          ]
        }
      }, status: :bad_request
      
    rescue ArgumentError => e
      render json: {
        success: false,
        error: 'Validation Error',
        message: e.message
      }, status: :bad_request
      
    rescue ActiveRecord::RecordNotFound => e
      render json: {
        success: false,
        error: 'Not Found',
        message: e.message
      }, status: :not_found
      
    rescue => e
      # Log the full error for debugging
      Rails.logger.error "SyncAccounts Error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      render json: {
        success: false,
        error: 'Internal Server Error',
        message: e.message,
        class: e.class.name
      }, status: :internal_server_error
    end
  end

  # GET /api/v1/sync_accounts/health
  # Health check endpoint for the sync service
  def health
    render json: {
      success: true,
      service: 'SyncAccounts',
      status: 'healthy',
      timestamp: Time.current.iso8601,
      version: '1.0.0'
    }, status: :ok
  end



  private

  def sync_params
    # 2025-06-11 04:55:00 - Fixed parameter parsing to accept direct parameters instead of nested under sync_accounts key
    # This allows the frontend to send data directly: { sm_store_id: 1, store_name: "...", ... }
    params.permit(
      :sm_store_id,
      :store_name, 
      :chatwoot_account_id,
      users: [:sm_user_id, :name, :username, :chatwoot_user_id]
    )
  end
end 