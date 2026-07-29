# frozen_string_literal: true

module Api
  module V1
    module AppleIap
      class ConsumptionRequestsController < Api::BaseController
        def update
          order = current_organization.apple_iap_orders.find_by(id: params[:order_id])
          return not_found_error(resource: "apple_iap_order") unless order

          consumption_request = order.apple_iap_consumption_requests.find_by(
            notification_uuid: params[:notification_uuid]
          )
          return not_found_error(resource: "apple_iap_consumption_request") unless consumption_request

          response_result = ::PaymentProviders::AppleIap::ConsumptionRequests::RespondService.call(
            consumption_request:,
            params: input_params.to_h.symbolize_keys
          )

          if response_result.success?
            render json: {
              apple_iap_consumption_request: {
                notification_uuid: consumption_request.notification_uuid,
                status: consumption_request.reload.status,
                sent_at: consumption_request.sent_at&.iso8601
              }
            }
          else
            render_error_response(response_result)
          end
        end

        private

        def input_params
          params.require(:consumption_response).permit(
            :response_event_id,
            :customer_consented,
            :delivery_status,
            :sample_content_provided,
            :consumption_percentage,
            :refund_preference,
            backend_snapshot: {}
          )
        end

        def resource_name
          "apple_iap_order"
        end
      end
    end
  end
end
