# frozen_string_literal: true

module Types
  module PaymentProviders
    class AppleIapUpdateInput < BaseInputObject
      description "Apple IAP update input arguments"

      argument :app_apple_id, GraphQL::Types::BigInt, required: false
      argument :bundle_id, String, required: false
      argument :code, String, required: false
      argument :id, ID, required: true
      argument :issuer_id, String, required: false
      argument :key_id, String, required: false
      argument :name, String, required: false
      argument :private_key, String, required: false
      argument :product_ids, [String], required: false
      argument :webhook_base_url, String, required: false
    end
  end
end
