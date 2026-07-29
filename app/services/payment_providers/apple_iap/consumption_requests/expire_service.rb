# frozen_string_literal: true

module PaymentProviders
  module AppleIap
    module ConsumptionRequests
      class ExpireService < BaseService
        Result = BaseResult

        def initialize(consumption_request:)
          @consumption_request = consumption_request

          super()
        end

        def call
          return result if completed?

          consumption_request.update!(status: :expired)
          Rails.logger.error(
            "Apple consumption deadline expired notification_uuid=" \
            "#{consumption_request.notification_uuid}"
          )
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
