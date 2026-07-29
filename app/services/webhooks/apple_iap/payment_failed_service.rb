# frozen_string_literal: true

module Webhooks
  module AppleIap
    class PaymentFailedService < BaseService
      private

      def webhook_type
        "apple_iap.payment_failed"
      end
    end
  end
end
