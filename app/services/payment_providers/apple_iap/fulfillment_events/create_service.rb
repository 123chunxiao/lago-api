# frozen_string_literal: true

module PaymentProviders
  module AppleIap
    module FulfillmentEvents
      class CreateService < BaseService
        EVENT_STATUS_MAP = {
          "entitlement.granted" => :entitlement_granted,
          "entitlement.reserved" => :processing,
          "clone.started" => :processing,
          "clone.succeeded" => :delivered,
          "clone.failed" => :failed,
          "clone.timed_out" => :timed_out,
          "entitlement.restored" => :entitlement_granted,
          "entitlement.revoked" => :failed
        }.freeze
        Result = BaseResult[:fulfillment_event]

        def initialize(order:, params:)
          @order = order
          @params = params

          super()
        end

        def call
          existing_event = order.apple_iap_fulfillment_events.find_by(event_id: params[:event_id])
          if existing_event
            return invalid(:event_id, "fulfillment_event_conflict") unless equivalent?(existing_event)

            result.fulfillment_event = existing_event
            return result
          end

          return invalid(:event_type, "invalid_fulfillment_event_type") unless fulfillment_status
          return invalid(:event_type, "invalid_fulfillment_state_transition") if downgrades_delivered_order?

          order.with_lock do
            return invalid(:fulfillment_version, "stale_fulfillment_version") unless next_version?

            event = order.apple_iap_fulfillment_events.create!(
              fulfillment_event_attributes.merge(organization: order.organization)
            )
            order.update!(
              fulfillment_status: fulfillment_status,
              fulfillment_version: params[:fulfillment_version]
            )
            result.fulfillment_event = event
          end
          result
        rescue ActiveRecord::RecordNotUnique
          event = order.apple_iap_fulfillment_events.find_by(event_id: params[:event_id])
          return invalid(:event_id, "fulfillment_event_conflict") unless event

          result.fulfillment_event = event
          result
        rescue ActiveRecord::RecordInvalid => e
          result.record_validation_failure!(record: e.record)
        end

        private

        attr_reader :order, :params

        def fulfillment_status
          EVENT_STATUS_MAP[params[:event_type]]
        end

        def next_version?
          params[:fulfillment_version].to_i == order.fulfillment_version + 1
        end

        def fulfillment_event_attributes
          params.slice(
            :event_id,
            :fulfillment_version,
            :event_type,
            :occurred_at,
            :payload
          ).merge(
            entitlement_status: params.dig(:entitlement, :status),
            entitlement_id: params.dig(:entitlement, :id),
            clone_status: params.dig(:clone_task, :status),
            clone_task_id: params.dig(:clone_task, :id),
            voice_id: params.dig(:clone_task, :voice_id),
            attempt_no: params.dig(:clone_task, :attempt_no),
            failure_code: params.dig(:failure, :code),
            failure_message: params.dig(:failure, :message)
          )
        end

        def equivalent?(event)
          event.fulfillment_version == params[:fulfillment_version].to_i &&
            event.event_type == params[:event_type]
        end

        def downgrades_delivered_order?
          order.fulfillment_delivered? && fulfillment_status != :delivered
        end

        def invalid(field, code)
          result.single_validation_failure!(field:, error_code: code)
        end
      end
    end
  end
end
