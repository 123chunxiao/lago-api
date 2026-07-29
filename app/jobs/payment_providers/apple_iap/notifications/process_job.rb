# frozen_string_literal: true

module PaymentProviders
  module AppleIap
    module Notifications
      class ProcessJob < ApplicationJob
        queue_as "providers"

        retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 5
        retry_on ActiveRecord::RecordNotFound, wait: :polynomially_longer, attempts: 10
        retry_on ActiveRecord::StaleObjectError, wait: :polynomially_longer, attempts: 5

        def perform(notification)
          ProcessService.call!(notification:)
        end
      end
    end
  end
end
