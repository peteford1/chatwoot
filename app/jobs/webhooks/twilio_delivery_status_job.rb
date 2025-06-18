class Webhooks::TwilioDeliveryStatusJob < ApplicationJob
  queue_as :low

  def perform(params = {})
    # 2025-06-04: Fix string/symbol key mismatch - controller sends string keys but service expects symbol keys
    # Convert string keys from permitted_params.to_unsafe_hash to symbol keys for compatibility
    symbolized_params = params.deep_symbolize_keys
    
    ::Twilio::DeliveryStatusService.new(params: symbolized_params).perform
  end
end
