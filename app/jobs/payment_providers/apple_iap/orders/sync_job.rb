# frozen_string_literal: true

module PaymentProviders
  module AppleIap
    module Orders
      class SyncJob < ApplicationJob
        queue_as "providers"

        retry_on BaseService::ServiceFailure, wait: :polynomially_longer, attempts: 10

        def perform(order)
          SyncService.call!(order:)
        end
      end
    end
  end
end
