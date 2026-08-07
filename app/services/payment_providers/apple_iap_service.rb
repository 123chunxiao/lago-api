# frozen_string_literal: true

module PaymentProviders
  class AppleIapService < BaseService
    ATTRIBUTES = %i[
      app_apple_id bundle_id code issuer_id key_id name private_key product_ids webhook_base_url
    ].freeze

    def create_or_update(**args)
      provider_result = PaymentProviders::FindService.call(
        organization_id: args[:organization].id,
        code: args[:code],
        id: args[:id],
        payment_provider_type: "apple_iap"
      )

      provider = if provider_result.success?
        provider_result.payment_provider
      else
        PaymentProviders::AppleIapProvider.new(
          organization_id: args[:organization].id,
          code: args[:code]
        )
      end

      ATTRIBUTES.each do |attribute|
        provider.public_send("#{attribute}=", args[attribute]) if args.key?(attribute)
      end
      provider.save!

      result.apple_iap_provider = provider
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end
  end
end
