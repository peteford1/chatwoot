class Webhooks::TwilioEventsJob < ApplicationJob
  queue_as :low

  def perform(params)
    ::Twilio::IncomingMessageService.new(params: params).perform
  end
end
