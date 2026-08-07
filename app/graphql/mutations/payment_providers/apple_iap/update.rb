# frozen_string_literal: true

module Mutations
  module PaymentProviders
    module AppleIap
      class Update < Base
        REQUIRED_PERMISSION = "organization:integrations:update"

        graphql_name "UpdateAppleIapPaymentProvider"
        description "Update Apple IAP payment provider"

        input_object_class Types::PaymentProviders::AppleIapUpdateInput

        type Types::PaymentProviders::AppleIap
      end
    end
  end
end
