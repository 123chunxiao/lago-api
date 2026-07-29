# frozen_string_literal: true

module V1
  module PaymentProviders
    class AppleIapSerializer < ModelSerializer
      def serialize
        {
          lago_id: model.id,
          code: model.code,
          name: model.name,
          payment_provider: model.payment_type,
          bundle_id: model.bundle_id,
          app_apple_id: model.app_apple_id,
          product_ids: model.product_ids,
          created_at: model.created_at.iso8601
        }
      end
    end
  end
end
