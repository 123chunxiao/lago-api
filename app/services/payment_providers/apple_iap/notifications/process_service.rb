# frozen_string_literal: true

module PaymentProviders
  module AppleIap
    module Notifications
      class ProcessService < BaseService
        SUPPORTED_TYPES = %w[
          TEST ONE_TIME_CHARGE CONSUMPTION_REQUEST REFUND REFUND_DECLINED REFUND_REVERSED
        ].freeze

        def initialize(notification:)
          @notification = notification

          super()
        end

        def call
          notification.with_lock do
            return result if notification.status_succeeded? || notification.status_ignored?

            notification.update!(status: :processing, attempts: notification.attempts + 1)
            process_notification
          end
          result
        rescue => e
          notification.update!(status: :failed, last_error: e.message)
          raise
        end

        private

        attr_reader :notification, :order

        def process_notification
          unless SUPPORTED_TYPES.include?(notification.notification_type)
            notification.update!(status: :ignored, processed_at: Time.current)
            return
          end

          if notification.notification_type == "TEST"
            notification.update!(status: :succeeded, processed_at: Time.current)
            return
          end

          verification = VerifySignedDataService.call(signed_data: data["signedTransactionInfo"])
          verification.raise_if_error!
          validation = TransactionValidatorService.call(
            payload: verification.payload,
            payment_provider:,
            expected_transaction_id: notification.transaction_id
          )
          validation.raise_if_error!

          @order = find_order(validation.attributes)
          notification.update!(apple_iap_order: order)
          apply_event(validation.attributes)
          notification.update!(status: :succeeded, processed_at: Time.current, last_error: nil)
        end

        def apply_event(attributes)
          case notification.notification_type
          when "ONE_TIME_CHARGE"
            handle_payment(attributes)
          when "CONSUMPTION_REQUEST"
            handle_consumption_request
          when "REFUND"
            handle_refund(attributes)
          when "REFUND_DECLINED"
            handle_refund_declined
          when "REFUND_REVERSED"
            handle_refund_reversed
          end
        end

        def handle_payment(attributes)
          order.update!(
            attributes.merge(
              payment_status: :succeeded,
              verified_at: order.verified_at || Time.current,
              failure_code: nil,
              failure_message: nil
            )
          )
          enqueue_webhook("apple_iap.payment_succeeded")
        end

        def handle_consumption_request
          order.update!(refund_status: :requested)
          consumption_request = order.apple_iap_consumption_requests.create!(
            organization: order.organization,
            apple_iap_notification: notification,
            notification_uuid: notification.notification_uuid,
            transaction_id: order.transaction_id,
            deadline_at: notification.received_at + 12.hours
          )
          schedule_consumption_deadline(consumption_request)
          enqueue_webhook(
            "apple_iap.consumption_requested",
            event_data: {
              consumption_request: {
                notification_uuid: consumption_request.notification_uuid,
                deadline_at: consumption_request.deadline_at.iso8601
              }
            }
          )
        end

        def handle_refund(attributes)
          order.update!(
            refund_status: refund_status,
            revocation_date: attributes[:revocation_date],
            revocation_reason: attributes[:revocation_reason],
            revocation_percentage: revocation_percentage
          )
          enqueue_webhook("apple_iap.refund_succeeded")
        end

        def schedule_consumption_deadline(consumption_request)
          deadline_job = PaymentProviders::AppleIap::ConsumptionRequests::DeadlineJob
          expire_job = PaymentProviders::AppleIap::ConsumptionRequests::ExpireJob
          after_commit do
            deadline_job
              .set(wait_until: consumption_request.deadline_at - 30.minutes)
              .perform_later(consumption_request)
            expire_job
              .set(wait_until: consumption_request.deadline_at)
              .perform_later(consumption_request)
          end
        end

        def handle_refund_declined
          order.update!(refund_status: :declined)
          enqueue_webhook("apple_iap.refund_declined")
        end

        def handle_refund_reversed
          order.update!(
            refund_status: :reversed,
            revocation_date: nil,
            revocation_reason: nil,
            revocation_percentage: nil
          )
          enqueue_webhook("apple_iap.refund_reversed")
        end

        def refund_status
          return :manual_review if partial_refund?

          :succeeded
        end

        def partial_refund?
          revocation_percentage.present? &&
            revocation_percentage.positive? &&
            revocation_percentage < 100_000
        end

        def revocation_percentage
          payload["summary"]&.dig("revocationPercentage")
        end

        def find_order(attributes)
          notification.organization.apple_iap_orders.find_by!(
            bundle_id: attributes[:bundle_id],
            environment: attributes[:environment],
            transaction_id: attributes[:transaction_id]
          )
        end

        def payload
          @payload ||= VerifySignedDataService.call(signed_data: notification.signed_payload).payload
        end

        def data
          payload.fetch("data", {})
        end

        def payment_provider
          @payment_provider ||= order&.payment_provider || provider_for_bundle!
        end

        def provider_for_bundle!
          provider = notification.organization.apple_iap_payment_providers.find do |candidate|
            candidate.bundle_id == data["bundleId"]
          end
          return provider if provider

          raise ActiveRecord::RecordNotFound, "Apple IAP provider not found for bundle"
        end

        def enqueue_webhook(type, event_data: {})
          after_commit do
            SendWebhookJob.perform_later(type, order, event_data:)
          end
        end
      end
    end
  end
end
