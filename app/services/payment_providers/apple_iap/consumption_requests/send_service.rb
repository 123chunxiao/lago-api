# frozen_string_literal: true

module PaymentProviders
  module AppleIap
    module ConsumptionRequests
      class SendService < BaseService
        Result = BaseResult[:consumption_request]

        def initialize(consumption_request:, client: nil)
          @consumption_request = consumption_request
          @client = client

          super()
        end

        def call
          return completed_result if consumption_request.status_sent?
          return expired_result if Time.current >= consumption_request.deadline_at

          consumption_request.update!(
            status: :sending,
            attempts: consumption_request.attempts + 1
          )
          apple_client.send_consumption_information(
            transaction_id: consumption_request.transaction_id,
            environment: consumption_request.apple_iap_order.environment,
            payload: consumption_request.apple_payload
          )
          consumption_request.update!(status: :sent, sent_at: Time.current, last_error: nil)
          completed_result
        rescue LagoHttpClient::HttpError => e
          consumption_request.update!(status: :failed, last_error: e.message)
          result.service_failure!(
            code: "apple_consumption_submission_failed",
            message: e.message,
            error: e
          )
        end

        private

        attr_reader :consumption_request

        def apple_client
          @client ||= Client.new(payment_provider: consumption_request.apple_iap_order.payment_provider)
        end

        def completed_result
          result.consumption_request = consumption_request
          result
        end

        def expired_result
          consumption_request.update!(status: :expired)
          result.single_validation_failure!(
            field: :deadline_at,
            error_code: "apple_consumption_deadline_expired"
          )
        end
      end
    end
  end
end
