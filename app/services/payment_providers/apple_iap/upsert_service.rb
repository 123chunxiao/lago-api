# frozen_string_literal: true

module PaymentProviders
  module AppleIap
    class UpsertService < BaseService
      Result = BaseResult[:payment_provider]

      def initialize(organization:, code:, params:)
        @organization = organization
        @code = code
        @params = params

        super
      end

      def call
        provider = existing_provider || PaymentProviders::AppleIapProvider.new(organization:, code:)
        provider.assign_attributes(provider_attributes)
        provider.save!

        result.payment_provider = provider
        result
      rescue ActiveRecord::RecordInvalid => e
        result.record_validation_failure!(record: e.record)
      end

      private

      attr_reader :organization, :code, :params

      def existing_provider
        organization.apple_iap_payment_providers.find_by(code:)
      end

      def provider_attributes
        params.slice(
          :name,
          :issuer_id,
          :key_id,
          :private_key,
          :bundle_id,
          :app_apple_id,
          :product_ids
        )
      end
    end
  end
end
