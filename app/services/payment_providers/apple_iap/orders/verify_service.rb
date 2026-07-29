# frozen_string_literal: true

module PaymentProviders
  module AppleIap
    module Orders
      class VerifyService < BaseService
        Result = BaseResult[:apple_iap_order]

        def initialize(organization:, params:, client: nil)
          @organization = organization
          @params = params
          @client = client

          super()
        end

        def call
          request_validation = validate_request
          return request_validation if request_validation

          return existing_order_result if existing_order
          return transaction_conflict_result if conflicting_transaction_order

          provider_result = find_provider
          if provider_result.failure?
            return result.single_validation_failure!(
              field: :payment_provider_code,
              error_code: provider_result.error.code
            )
          end

          @payment_provider = provider_result.payment_provider
          client_transaction_result = verified_transaction(params[:signed_transaction])
          return result_from(client_transaction_result) if client_transaction_result.failure?

          client_validation_result = validate_transaction(client_transaction_result.payload)
          return result_from(client_validation_result) if client_validation_result.failure?

          @client_attributes = client_validation_result.attributes
          create_verifying_order!
          verify_with_apple!
        rescue ActiveRecord::RecordNotUnique
          @existing_order = nil
          return existing_order_result if existing_order

          transaction_conflict_result
        rescue LagoHttpClient::HttpError => e
          handle_apple_error(e)
        rescue ActiveRecord::RecordInvalid => e
          result.record_validation_failure!(record: e.record)
        end

        private

        attr_reader :organization, :params, :payment_provider, :client_attributes

        def validate_request
          %i[
            business_request_id external_customer_id app_account_token transaction_id
            product_id signed_transaction
          ].each do |field|
            if params[field].blank?
              return result.single_validation_failure!(
                field:,
                error_code: "#{field}_missing"
              )
            end
          end

          unless valid_uuid?(params[:business_request_id])
            return result.single_validation_failure!(
              field: :business_request_id,
              error_code: "invalid_uuid"
            )
          end
          unless valid_uuid?(params[:app_account_token])
            return result.single_validation_failure!(
              field: :app_account_token,
              error_code: "invalid_uuid"
            )
          end
          if params[:signed_transaction].bytesize > 65_536
            return result.single_validation_failure!(
              field: :signed_transaction,
              error_code: "signed_transaction_too_large"
            )
          end

          nil
        end

        def valid_uuid?(value)
          value.to_s.match?(
            /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i
          )
        end

        def existing_order
          return @existing_order if defined?(@existing_order)

          @existing_order = organization.apple_iap_orders.find_by(
            business_request_id: params[:business_request_id]
          )
        end

        def existing_order_result
          unless existing_order
            return result.single_validation_failure!(
              field: :business_request_id,
              error_code: "apple_iap_order_not_found"
            )
          end

          unless same_idempotent_request?
            return result.single_validation_failure!(
              field: :business_request_id,
              error_code: "business_request_id_conflict"
            )
          end

          result.apple_iap_order = existing_order
          result
        end

        def same_idempotent_request?
          existing_order.transaction_id == params[:transaction_id].to_s &&
            existing_order.product_id == params[:product_id] &&
            existing_order.external_customer_id == params[:external_customer_id] &&
            existing_order.app_account_token.to_s == params[:app_account_token].to_s
        end

        def conflicting_transaction_order
          return @conflicting_transaction_order if defined?(@conflicting_transaction_order)

          @conflicting_transaction_order = organization.apple_iap_orders.find_by(
            transaction_id: params[:transaction_id]
          )
        end

        def transaction_conflict_result
          result.single_validation_failure!(
            field: :transaction_id,
            error_code: "apple_transaction_already_registered"
          )
        end

        def find_provider
          PaymentProviders::FindService.call(
            organization_id: organization.id,
            code: params[:payment_provider_code],
            payment_provider_type: "apple_iap"
          )
        end

        def verified_transaction(signed_transaction)
          PaymentProviders::AppleIap::VerifySignedDataService.call(
            signed_data: signed_transaction
          )
        end

        def validate_transaction(
          payload,
          expected_transaction_id: params[:transaction_id],
          expected_app_account_token: params[:app_account_token]
        )
          PaymentProviders::AppleIap::TransactionValidatorService.call(
            payload:,
            payment_provider:,
            expected_transaction_id:,
            expected_product_id: params[:product_id],
            expected_app_account_token:
          )
        end

        def create_verifying_order!
          @apple_iap_order = organization.apple_iap_orders.create!(
            client_attributes.merge(
              payment_provider:,
              business_request_id: params[:business_request_id],
              external_customer_id: params[:external_customer_id],
              app_account_token: params[:app_account_token].presence || client_attributes[:app_account_token],
              app_apple_id: payment_provider.app_apple_id,
              signed_transaction: params[:signed_transaction],
              metadata: params[:metadata] || {}
            )
          )
        end

        def verify_with_apple!
          response = apple_client.transaction_info(
            transaction_id: @apple_iap_order.transaction_id,
            environment: @apple_iap_order.environment
          )
          server_transaction_result = verified_transaction(response.fetch("signedTransactionInfo"))
          return fail_order_from(server_transaction_result) if server_transaction_result.failure?

          server_validation_result = validate_transaction(
            server_transaction_result.payload,
            expected_transaction_id: @apple_iap_order.transaction_id,
            expected_app_account_token: @apple_iap_order.app_account_token
          )
          return fail_order_from(server_validation_result) if server_validation_result.failure?
          if server_validation_result.attributes[:revocation_date]
            return fail_revoked_order(server_validation_result.attributes)
          end

          @apple_iap_order.update!(
            server_validation_result.attributes.merge(
              payment_status: :succeeded,
              verified_at: Time.current,
              signed_transaction: response.fetch("signedTransactionInfo"),
              failure_code: nil,
              failure_message: nil
            )
          )
          after_commit do
            SendWebhookJob.perform_later("apple_iap.payment_succeeded", @apple_iap_order)
          end
          result.apple_iap_order = @apple_iap_order
          result
        end

        def fail_order_from(failed_result)
          error = failed_result.error
          fail_order!(
            code: "apple_transaction_validation_failed",
            message: error.message
          )
          result.fail_with_error!(error)
        end

        def fail_revoked_order(attributes)
          fail_order!(
            code: "apple_transaction_revoked",
            message: "Apple transaction is already revoked",
            attributes:
          )
          result.single_validation_failure!(
            field: :transaction_id,
            error_code: "apple_transaction_revoked"
          )
        end

        def fail_order!(code:, message:, attributes: {})
          @apple_iap_order.update!(
            attributes.merge(
              payment_status: :failed,
              failure_code: code,
              failure_message: message
            )
          )
          after_commit do
            enqueue_payment_failed_webhook(code:, message:)
          end
        end

        def enqueue_payment_failed_webhook(code:, message:)
          SendWebhookJob.perform_later(
            "apple_iap.payment_failed",
            @apple_iap_order,
            event_data: {failure_code: code, failure_message: message}
          )
        end

        def handle_apple_error(error)
          if @apple_iap_order
            @apple_iap_order.update!(
              failure_code: "apple_api_unavailable",
              failure_message: error.message
            )
            after_commit do
              PaymentProviders::AppleIap::Orders::SyncJob.perform_later(@apple_iap_order)
            end
            result.apple_iap_order = @apple_iap_order
            return result
          end

          result.single_validation_failure!(
            field: :transaction_id,
            error_code: "apple_api_unavailable"
          )
        end

        def apple_client
          @client ||= PaymentProviders::AppleIap::Client.new(payment_provider:)
        end

        def result_from(other_result)
          result.fail_with_error!(other_result.error)
        end
      end
    end
  end
end
