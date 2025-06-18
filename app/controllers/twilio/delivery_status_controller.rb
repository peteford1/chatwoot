class Twilio::DeliveryStatusController < ApplicationController
  # 2025-06-04: Added webhook security to prevent direct access - force requests through KrakenD gateway  
  include WebhookSecurity
  
  def create
    Webhooks::TwilioDeliveryStatusJob.perform_later(permitted_params.to_unsafe_hash)

    head :no_content
  end

  private

  def permitted_params
    params.permit(
      :AccountSid,
      :From,
      :MessageSid,
      :MessagingServiceSid,
      :MessageStatus,
      :ErrorCode,
      :ErrorMessage
    )
  end
end
