# frozen_string_literal: true

module V1
  class AppleIapWebhookOrderSerializer < AppleIapOrderSerializer
    def serialize
      super.merge(options.fetch(:event_data, {}))
    end
  end
end
