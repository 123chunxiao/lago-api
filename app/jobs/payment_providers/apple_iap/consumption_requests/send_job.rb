# frozen_string_literal: true

module PaymentProviders
  module AppleIap
    module ConsumptionRequests
      class SendJob < ApplicationJob
        queue_as "providers"

        retry_on BaseService::ServiceFailure, wait: :polynomially_longer, attempts: 10

        def perform(consumption_request)
          SendService.call!(consumption_request:)
        end
      end
    end
  end
end
