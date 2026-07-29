# frozen_string_literal: true

module PaymentProviders
  module AppleIap
    module Notifications
      class CreateService < BaseService
        Result = BaseResult[:notification]

        def initialize(organization_id:, code:, signed_payload:)
          @organization_id = organization_id
          @code = code
          @signed_payload = signed_payload

          super()
        end

        def call
          return invalid_notification("apple_signed_payload_missing") if signed_payload.blank?
          if signed_payload.bytesize > 131_072
            return invalid_notification("apple_signed_payload_too_large")
          end

          provider_result = find_provider
          return result.fail_with_error!(provider_result.error) if provider_result.failure?

          @payment_provider = provider_result.payment_provider
          signed_data_result = VerifySignedDataService.call(signed_data: signed_payload)
          return result.fail_with_error!(signed_data_result.error) if signed_data_result.failure?

          @payload = signed_data_result.payload
          return invalid_notification("apple_notification_uuid_missing") if payload["notificationUUID"].blank?
          return invalid_notification("apple_bundle_id_mismatch") unless data["bundleId"] == payment_provider.bundle_id
          return invalid_notification("apple_app_id_mismatch") unless app_id_matches?
          return result.fail_with_error!(transaction_verification.error) if transaction_verification&.failure?
          return invalid_notification("apple_transaction_bundle_id_mismatch") unless transaction_bundle_matches?
          return invalid_notification("apple_transaction_environment_mismatch") unless transaction_environment_matches?

          @notification = organization.apple_iap_notifications.find_or_initialize_by(
            notification_uuid: payload["notificationUUID"]
          )
          if notification.persisted?
            unless notification.status_succeeded? ||
                notification.status_ignored? ||
                notification.status_processing?
              ProcessJob.perform_later(notification)
            end
            result.notification = notification
            return result
          end

          notification.assign_attributes(
            notification_type: payload["notificationType"],
            subtype: payload["subtype"],
            environment: normalized_environment,
            transaction_id: transaction_id,
            signed_payload:,
            received_at: Time.current
          )
          notification.save!
          after_commit { ProcessJob.perform_later(notification) }

          result.notification = notification
          result
        rescue ActiveRecord::RecordNotUnique
          result.notification = organization.apple_iap_notifications.find_by!(
            notification_uuid: payload["notificationUUID"]
          )
          result
        rescue ActiveRecord::RecordInvalid => e
          result.record_validation_failure!(record: e.record)
        end

        private

        attr_reader :organization_id, :code, :signed_payload, :payment_provider, :payload, :notification

        def find_provider
          PaymentProviders::FindService.call(
            organization_id:,
            code:,
            payment_provider_type: "apple_iap"
          )
        end

        def organization
          @organization ||= Organization.find(organization_id)
        end

        def data
          @data ||= payload.fetch("data", {})
        end

        def app_id_matches?
          data["appAppleId"].blank? ||
            payment_provider.app_apple_id.blank? ||
            data["appAppleId"].to_s == payment_provider.app_apple_id.to_s
        end

        def transaction_id
          transaction_payload["transactionId"]&.to_s
        end

        def transaction_payload
          return {} if data["signedTransactionInfo"].blank?

          transaction_verification&.payload || {}
        end

        def transaction_verification
          return if data["signedTransactionInfo"].blank?

          @transaction_verification ||= VerifySignedDataService.call(
            signed_data: data["signedTransactionInfo"]
          )
        end

        def transaction_bundle_matches?
          transaction_payload.blank? || transaction_payload["bundleId"] == payment_provider.bundle_id
        end

        def transaction_environment_matches?
          transaction_payload.blank? ||
            transaction_payload["environment"].to_s.downcase == normalized_environment
        end

        def normalized_environment
          data["environment"]&.downcase
        end

        def invalid_notification(code)
          result.single_validation_failure!(field: :signed_payload, error_code: code)
        end
      end
    end
  end
end
