# frozen_string_literal: true

module Api
  module V1
    module AppleIap
      class FulfillmentEventsController < Api::BaseController
        def create
          order = current_organization.apple_iap_orders.find_by(id: params[:order_id])
          return not_found_error(resource: "apple_iap_order") unless order

          create_result = ::PaymentProviders::AppleIap::FulfillmentEvents::CreateService.call(
            order:,
            params: input_params.to_h.symbolize_keys
          )

          if create_result.success?
            render json: {
              apple_iap_fulfillment_event: {
                event_id: create_result.fulfillment_event.event_id,
                fulfillment_version: create_result.fulfillment_event.fulfillment_version,
                fulfillment_status: order.reload.fulfillment_status
              }
            }
          else
            render_error_response(create_result)
          end
        end

        private

        def input_params
          params.require(:fulfillment_event).permit(
            :event_id,
            :fulfillment_version,
            :event_type,
            :occurred_at,
            entitlement: %i[id status],
            clone_task: %i[id status attempt_no voice_id],
            failure: %i[code message retryable],
            payload: {}
          )
        end

        def resource_name
          "apple_iap_order"
        end
      end
    end
  end
end
