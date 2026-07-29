# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::AppleIap::BaseService do
  subject(:webhook_service) { service_class.new(object: order, options:) }

  let(:order) { create(:apple_iap_order) }
  let(:options) { {} }

  {
    Webhooks::AppleIap::PaymentSucceededService => "apple_iap.payment_succeeded",
    Webhooks::AppleIap::PaymentFailedService => "apple_iap.payment_failed",
    Webhooks::AppleIap::ConsumptionRequestedService => "apple_iap.consumption_requested",
    Webhooks::AppleIap::RefundSucceededService => "apple_iap.refund_succeeded",
    Webhooks::AppleIap::RefundDeclinedService => "apple_iap.refund_declined",
    Webhooks::AppleIap::RefundReversedService => "apple_iap.refund_reversed"
  }.each do |klass, webhook_type|
    context "with #{klass}" do
      let(:service_class) { klass }

      it_behaves_like "creates webhook", webhook_type, "apple_iap_order", {
        "lago_id" => String,
        "business_request_id" => String,
        "transaction_id" => String,
        "payment_status" => String,
        "refund_status" => String,
        "fulfillment_status" => String
      }
    end
  end
end
