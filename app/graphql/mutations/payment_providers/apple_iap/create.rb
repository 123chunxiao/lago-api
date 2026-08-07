# frozen_string_literal: true

module Mutations
  module PaymentProviders
    module AppleIap
      class Create < Base
        REQUIRED_PERMISSION = "organization:integrations:create"

        graphql_name "AddAppleIapPaymentProvider"
        description "Add Apple IAP payment provider"

        input_object_class Types::PaymentProviders::AppleIapInput

        type Types::PaymentProviders::AppleIap
      end
    end
  end
end
