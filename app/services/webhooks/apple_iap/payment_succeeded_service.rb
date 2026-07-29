# frozen_string_literal: true

module Webhooks
  module AppleIap
    class PaymentSucceededService < BaseService
      private

      def webhook_type
        "apple_iap.payment_succeeded"
      end
    end
  end
end
