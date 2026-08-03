# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::AppleIap::Notifications::ProcessService do
  subject(:result) { described_class.call(notification:) }

  let(:order) { create(:apple_iap_order) }
  let(:notification) do
    create(
      :apple_iap_notification,
      organization: order.organization,
      apple_iap_order: nil,
      notification_type: "TEST",
      transaction_id: nil
    )
  end

  it "marks an App Store test notification as succeeded" do
    expect(result).to be_success
    expect(notification.reload).to be_status_succeeded
  end
end
