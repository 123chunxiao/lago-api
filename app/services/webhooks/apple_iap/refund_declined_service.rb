# frozen_string_literal: true

module Webhooks
  module AppleIap
    class RefundDeclinedService < BaseService
      private

      def webhook_type
        "apple_iap.refund_declined"
      end
    end
  end
end
