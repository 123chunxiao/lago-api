# frozen_string_literal: true

module Webhooks
  module AppleIap
    class RefundReversedService < BaseService
      private

      def webhook_type
        "apple_iap.refund_reversed"
      end
    end
  end
end
