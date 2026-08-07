# frozen_string_literal: true

module PaymentProviders
  module AppleIap
    module Orders
      class SyncService < BaseService
        Result = BaseResult[:apple_iap_order]

        def initialize(order:, client: nil)
          @order = order
          @client = client

          super()
        end

        def call
          response = apple_client.transaction_info(
            transaction_id: order.transaction_id,
            environment: order.environment
          )
          signed_transaction = response.fetch("signedTransactionInfo")
          verification = VerifySignedDataService.call(signed_data: signed_transaction)
          return result.fail_with_error!(verification.error) if verification.failure?

          validation = TransactionValidatorService.call(
            payload: verification.payload,
            payment_provider: order.payment_provider,
            expected_transaction_id: order.transaction_id,
            expected_product_id: order.product_id,
            expected_app_account_token: order.app_account_token
          )
          return result.fail_with_error!(validation.error) if validation.failure?

          update_order(validation.attributes, signed_transaction:)
          result.apple_iap_order = order
          result
        rescue LagoHttpClient::HttpError => e
          result.service_failure!(
            code: "apple_api_unavailable",
            message: e.message,
            error: e
          )
        end

        private

        attr_reader :order

        def update_order(attributes, signed_transaction:)
          was_succeeded = nil
          was_refunded = nil
          order.with_lock do
            was_succeeded = order.payment_succeeded?
            was_refunded = order.refund_succeeded? || order.refund_manual_review?
            order.update!(
              attributes.merge(
                payment_status: :succeeded,
                refund_status: attributes[:revocation_date] ? :succeeded : order.refund_status,
                verified_at: Time.current,
                signed_transaction:,
                failure_code: nil,
                failure_message: nil
              )
            )
            PaymentProviders::AppleIap::Payments::UpsertService.call!(
              order:,
              create_invoice: order.invoice_creation_requested?
            )
          end

          after_commit do
            SendWebhookJob.perform_later("apple_iap.payment_succeeded", order) unless was_succeeded
            if attributes[:revocation_date] && !was_refunded
              SendWebhookJob.perform_later("apple_iap.refund_succeeded", order)
            end
          end
        end

        def apple_client
          @client ||= Client.new(payment_provider: order.payment_provider)
        end
      end
    end
  end
end
