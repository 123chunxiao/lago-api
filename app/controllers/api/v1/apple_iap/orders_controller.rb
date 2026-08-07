# frozen_string_literal: true

module Api
  module V1
    module AppleIap
      class OrdersController < Api::BaseController
        def verify
          return invalid_idempotency_key unless valid_idempotency_key?

          verify_result = ::PaymentProviders::AppleIap::Orders::VerifyService.call(
            organization: current_organization,
            params: input_params.to_h.symbolize_keys
          )

          if verify_result.success?
            render_order(
              verify_result.apple_iap_order,
              status: verify_result.apple_iap_order.payment_verifying? ? :accepted : :ok
            )
          else
            render_error_response(verify_result)
          end
        end

        def show
          order = current_organization.apple_iap_orders.find_by(id: params[:id])
          return not_found_error(resource: "apple_iap_order") unless order

          enqueue_reconciliation(order)
          render_order(order)
        end

        def lookup
          if params[:business_request_id].blank? && params[:transaction_id].blank?
            return validation_errors(
              errors: {base: ["business_request_id_or_transaction_id_required"]}
            )
          end

          order = lookup_scope.first
          return not_found_error(resource: "apple_iap_order") unless order

          enqueue_reconciliation(order)
          render_order(order)
        end

        private

        def input_params
          params.require(:apple_iap_order).permit(
            :business_request_id,
            :external_customer_id,
            :app_account_token,
            :transaction_id,
            :product_id,
            :signed_transaction,
            :payment_provider_code,
            :lago_invoice_id,
            :create_invoice,
            metadata: {}
          )
        end

        def lookup_scope
          current_organization.apple_iap_orders.where(
            {
              business_request_id: params[:business_request_id],
              transaction_id: params[:transaction_id]
            }.compact
          )
        end

        def valid_idempotency_key?
          request.headers["Idempotency-Key"].present? &&
            ActiveSupport::SecurityUtils.secure_compare(
              request.headers["Idempotency-Key"],
              input_params[:business_request_id].to_s
            )
        end

        def invalid_idempotency_key
          validation_errors(
            errors: {business_request_id: ["idempotency_key_must_match_business_request_id"]}
          )
        end

        def render_order(order, status: :ok)
          render(
            json: ::V1::AppleIapOrderSerializer.new(order, root_name: "apple_iap_order"),
            status:
          )
        end

        def enqueue_reconciliation(order)
          if order.payment_verifying?
            ::PaymentProviders::AppleIap::Orders::SyncJob.perform_later(order)
          end
        end

        def resource_name
          "apple_iap_order"
        end
      end
    end
  end
end
