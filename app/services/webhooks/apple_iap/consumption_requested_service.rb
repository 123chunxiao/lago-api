# frozen_string_literal: true

module Webhooks
  module AppleIap
    class ConsumptionRequestedService < BaseService
      private

      def webhook_type
        "apple_iap.consumption_requested"
      end
    end
  end
end
