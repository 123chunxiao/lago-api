# frozen_string_literal: true

module Types
  module PaymentProviders
    class ProviderTypeEnum < Types::BaseEnum
      Customer::PAYMENT_PROVIDERS.each do |type|
        value type
      end

      value "apple_iap"
    end
  end
end
