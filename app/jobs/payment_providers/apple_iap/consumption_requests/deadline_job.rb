# frozen_string_literal: true

module PaymentProviders
  module AppleIap
    module ConsumptionRequests
      class DeadlineJob < ApplicationJob
        queue_as "providers"

        def perform(consumption_request)
          DeadlineService.call!(consumption_request:)
        end
      end
    end
  end
end
