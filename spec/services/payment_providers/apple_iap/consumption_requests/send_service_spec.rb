# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::AppleIap::ConsumptionRequests::SendService do
  subject(:result) { described_class.call(consumption_request:, client:) }

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
      deadline_at: 1.hour.from_now,
      status: :ready,
      apple_payload: {
        customerConsented: true,
        deliveryStatus: "DELIVERED",
        sampleContentProvided: false,
        consumptionPercentage: 100_000
      }
    )
  end
  let(:client) { instance_double(PaymentProviders::AppleIap::Client) }

  before do
    allow(client).to receive(:send_consumption_information)
  end

  it "submits the consumption response and marks it as sent" do
    expect(result).to be_success
    expect(consumption_request.reload).to be_status_sent
    expect(client).to have_received(:send_consumption_information).with(
      transaction_id: order.transaction_id,
      environment: "sandbox",
      payload: consumption_request.apple_payload
    )
  end
end
