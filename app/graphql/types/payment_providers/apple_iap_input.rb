# frozen_string_literal: true

module Types
  module PaymentProviders
    class AppleIapInput < BaseInputObject
      description "Apple IAP input arguments"

      argument :app_apple_id, GraphQL::Types::BigInt, required: true
      argument :bundle_id, String, required: true
      argument :code, String, required: true
      argument :issuer_id, String, required: true
      argument :key_id, String, required: true
      argument :name, String, required: true
      argument :private_key, String, required: true
      argument :product_ids, [String], required: true
      argument :webhook_base_url, String, required: false
    end
  end
end
