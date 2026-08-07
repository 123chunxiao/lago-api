# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::AppleIap::ConsumptionRequests::RespondService do
  subject(:result) { described_class.call(consumption_request:, params:) }

  let(:order) { create(:apple_iap_order) }
  let(:notification) do
    create(
      :apple_iap_notification,
      organization: order.organization,
      apple_iap_order: order
    )
  end
  let(:consumption_request) do
    AppleIapConsumptionRequest.create!(
      organization: order.organization,
      apple_iap_order: order,
      apple_iap_notification: notification,
      notification_uuid: notification.notification_uuid,
      transaction_id: order.transaction_id,
      deadline_at: 1.hour.from_now
    )
  end
  let(:params) do
    {
      response_event_id: SecureRandom.uuid,
      customer_consented: true,
      delivery_status: "DELIVERED",
      sample_content_provided: false,
      consumption_percentage: 25_000
    }
  end

  before do
    allow(PaymentProviders::AppleIap::ConsumptionRequests::SendJob).to receive(:perform_later)
  end

  it "accepts an Apple consumption percentage within the documented range" do
    expect(result).to be_success
    expect(consumption_request.reload.apple_payload).to eq(
      "customerConsented" => true,
      "deliveryStatus" => "DELIVERED",
      "sampleContentProvided" => false,
      "consumptionPercentage" => 25_000
    )
  end
end
