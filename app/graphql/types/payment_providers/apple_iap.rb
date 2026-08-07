# frozen_string_literal: true

module Types
  module PaymentProviders
    class AppleIap < Types::BaseObject
      graphql_name "AppleIapProvider"

      field :app_apple_id, GraphQL::Types::BigInt, null: false, permission: "organization:integrations:view"
      field :bundle_id, String, null: false, permission: "organization:integrations:view"
      field :code, String, null: false
      field :id, ID, null: false
      field :issuer_id, String, null: false, permission: "organization:integrations:view"
      field :key_id, String, null: false, permission: "organization:integrations:view"
      field :name, String, null: false
      field :private_key, ObfuscatedStringType, null: true, permission: "organization:integrations:view"
      field :product_ids, [String], null: false, permission: "organization:integrations:view"
      field :webhook_base_url, String, null: true, permission: "organization:integrations:view"
    end
  end
end
