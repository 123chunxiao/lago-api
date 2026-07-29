# frozen_string_literal: true

module Webhooks
  module AppleIap
    class RefundSucceededService < BaseService
      private

      def webhook_type
        "apple_iap.refund_succeeded"
      end
    end
  end
end
