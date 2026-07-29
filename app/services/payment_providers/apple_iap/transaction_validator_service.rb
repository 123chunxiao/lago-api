# frozen_string_literal: true

module PaymentProviders
  module AppleIap
    class TransactionValidatorService < BaseService
      Result = BaseResult[:attributes]

      def initialize(
        payload:,
        payment_provider:,
        expected_transaction_id: nil,
        expected_product_id: nil,
        expected_app_account_token: nil
      )
        @payload = payload
        @payment_provider = payment_provider
        @expected_transaction_id = expected_transaction_id
        @expected_product_id = expected_product_id
        @expected_app_account_token = expected_app_account_token

        super()
      end

      def call
        return invalid(:bundle_id, "apple_bundle_id_mismatch") unless payload["bundleId"] == payment_provider.bundle_id
        return invalid(:product_id, "apple_product_not_allowed") unless product_allowed?
        return invalid(:product_type, "apple_product_must_be_consumable") unless payload["type"] == "Consumable"
        return invalid(:quantity, "apple_quantity_must_equal_one") unless payload.fetch("quantity", 1).to_i == 1
        return invalid(:transaction_id, "apple_transaction_id_mismatch") unless transaction_id_matches?
        return invalid(:product_id, "apple_product_id_mismatch") unless product_id_matches?
        return invalid(:app_account_token, "apple_app_account_token_mismatch") unless app_account_token_matches?
        return invalid(:environment, "invalid_apple_environment") unless environment

        result.attributes = attributes
        result
      end

      private

      attr_reader :payload,
        :payment_provider,
        :expected_transaction_id,
        :expected_product_id,
        :expected_app_account_token

      def product_allowed?
        Array(payment_provider.product_ids).include?(payload["productId"])
      end

      def transaction_id_matches?
        expected_transaction_id.blank? || payload["transactionId"].to_s == expected_transaction_id.to_s
      end

      def product_id_matches?
        expected_product_id.blank? || payload["productId"] == expected_product_id
      end

      def app_account_token_matches?
        expected_app_account_token.blank? ||
          payload["appAccountToken"].to_s == expected_app_account_token.to_s
      end

      def environment
        case payload["environment"]&.downcase
        when "sandbox" then "sandbox"
        when "production" then "production"
        end
      end

      def attributes
        {
          app_account_token: payload["appAccountToken"],
          transaction_id: payload["transactionId"].to_s,
          original_transaction_id: payload["originalTransactionId"].to_s.presence,
          product_id: payload["productId"],
          bundle_id: payload["bundleId"],
          environment:,
          product_type: payload["type"],
          quantity: payload.fetch("quantity", 1).to_i,
          price_milliunits: payload["price"],
          currency: payload["currency"],
          purchased_at: timestamp(payload["purchaseDate"]),
          revocation_date: timestamp(payload["revocationDate"]),
          revocation_reason: payload["revocationReason"]
        }
      end

      def timestamp(value)
        return if value.blank?

        Time.zone.at(value.to_i / 1000.0)
      end

      def invalid(field, code)
        result.single_validation_failure!(field:, error_code: code)
      end
    end
  end
end
