class Twilio::CallbackController < ApplicationController
  # 2025-06-04: Added webhook security to prevent direct access - force requests through KrakenD gateway
  include WebhookSecurity
  
  def create
    Webhooks::TwilioEventsJob.perform_later(permitted_params.to_unsafe_hash)

    head :no_content
  end

  private

  def permitted_params # rubocop:disable Metrics/MethodLength
    params.permit(
      :ApiVersion,
      :SmsSid,
      :From,
      :ToState,
      :ToZip,
      :AccountSid,
      :MessageSid,
      :FromCountry,
      :ToCity,
      :FromCity,
      :To,
      :FromZip,
      :Body,
      :ToCountry,
      :FromState,
      :MediaUrl0,
      :MediaContentType0,
      :MessagingServiceSid
    )
  end
end
