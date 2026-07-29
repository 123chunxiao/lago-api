# frozen_string_literal: true

module Webhooks
  module AppleIap
    class BaseService < Webhooks::BaseService
      private

      def object_serializer
        ::V1::AppleIapWebhookOrderSerializer.new(
          object,
          root_name: object_type,
          event_data: options.fetch(:event_data, {})
        )
      end

      def object_type
        "apple_iap_order"
      end
    end
  end
end
