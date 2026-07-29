# frozen_string_literal: true

module PaymentProviders
  module AppleIap
    module ConsumptionRequests
      class DeadlineService < BaseService
        Result = BaseResult

        def initialize(consumption_request:)
          @consumption_request = consumption_request

          super()
        end

        def call
          return result if completed?

          if consumption_request.status_awaiting_backend?
            Rails.logger.error(
              "Apple consumption response missing notification_uuid=" \
              "#{consumption_request.notification_uuid}"
            )
          else
            SendJob.perform_later(consumption_request)
          end
          result
        end

        private

        attr_reader :consumption_request

        def completed?
          consumption_request.status_sent? ||
            consumption_request.status_skipped_no_consent? ||
            consumption_request.status_expired?
        end
      end
    end
  end
end
