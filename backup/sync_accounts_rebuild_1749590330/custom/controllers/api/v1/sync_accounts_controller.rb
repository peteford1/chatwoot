# SyncAccounts API Controller
# Created: 2025-06-10 13:15:00
# Purpose: REST API endpoint for synchronizing users between external systems and Chatwoot
# Description: Provides POST endpoint for account/user synchronization

class Api::V1::SyncAccountsController < Api::V1::BaseController
  # 2025-06-10 13:15:00 - Skip authentication for this endpoint temporarily for testing
  # Comment: Will add proper authentication based on user requirements
  skip_before_action :authenticate_user!, only: [:sync]
  skip_before_action :check_authorization, only: [:sync]

  # POST /api/v1/sync_accounts
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
  def sync
    begin
      # Load the custom service
      require_relative '../../../services/sync_accounts_service'
      
      service = SyncAccountsService.new
      result = service.sync_accounts(sync_params.to_h.deep_symbolize_keys)
      
      render json: {
        success: true,
        data: result
      }, status: :ok
      
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
        message: Rails.env.development? ? e.message : 'An unexpected error occurred'
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

  # GET /api/v1/sync_accounts/info
  # Information about the sync service
  def info
    render json: {
      service: 'SyncAccounts',
      description: 'Synchronizes users between external systems and Chatwoot accounts',
      version: '1.0.0',
      endpoints: {
        sync: {
          method: 'POST',
          path: '/api/v1/sync_accounts',
          description: 'Synchronize users and accounts'
        },
        health: {
          method: 'GET', 
          path: '/api/v1/sync_accounts/health',
          description: 'Service health check'
        }
      },
      input_format: {
        sm_store_id: 'string (required)',
        store_name: 'string (required)',
        chatwoot_account_id: 'integer (required)',
        users: [
          {
            sm_user_id: 'string (required)',
            name: 'string (required)',
            username: 'string (required)',
            chatwoot_user_id: 'integer (optional)'
          }
        ]
      },
      output_format: {
        sm_store_id: 'string',
        store_name: 'string', 
        chatwoot_account_id: 'integer',
        account_changed: 'boolean',
        users: [
          {
            sm_user_id: 'string',
            name: 'string',
            username: 'string',
            chatwoot_user_id: 'integer',
            changed_flag: 'boolean'
          }
        ],
        processed_at: 'ISO 8601 timestamp',
        summary: {
          total_users: 'integer',
          changed_users: 'integer',
          errors: 'integer'
        }
      }
    }, status: :ok
  end

  private

  def sync_params
    params.require(:sync_accounts).permit(
      :sm_store_id,
      :store_name, 
      :chatwoot_account_id,
      users: [:sm_user_id, :name, :username, :chatwoot_user_id]
    )
  end
end 