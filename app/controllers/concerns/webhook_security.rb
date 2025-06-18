module WebhookSecurity
  extend ActiveSupport::Concern

  included do
    # 2025-06-04: Added webhook security to restrict direct access - only allow KrakenD gateway
    # 2025-06-06: Temporarily disabled for local testing
    # before_action :verify_gateway_access, only: [:create], if: :webhook_endpoint?
  end

  private

  def webhook_endpoint?
    # Check if this is a webhook endpoint that should be protected
    controller_name == 'callback' && 
    (params[:controller]&.include?('twilio') || request.path.include?('/twilio/'))
  end

  def verify_gateway_access
    # Check for KrakenD-specific headers that prove the request came through our security gateway
    krakend_version = request.headers['X-Krakend']
    krakend_completed = request.headers['X-Krakend-Completed']
    
    # If neither header is present, this is likely a direct access attempt
    unless krakend_version.present? || krakend_completed.present?
      Rails.logger.warn "Webhook Security: Direct access attempt blocked from IP: #{request.remote_ip}"
      render json: { error: 'Direct webhook access not allowed' }, status: :forbidden
      return false
    end

    # Log successful gateway access for monitoring
    Rails.logger.info "Webhook Security: Request verified from KrakenD gateway (#{krakend_version})"
    true
  end
end 