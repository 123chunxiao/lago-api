# frozen_string_literal: true

module PaymentProviders
  module AppleIap
    module ConsumptionRequests
      class ExpireJob < ApplicationJob
        queue_as "providers"

        def perform(consumption_request)
          ExpireService.call!(consumption_request:)
        end
      end
    end
  end
end
