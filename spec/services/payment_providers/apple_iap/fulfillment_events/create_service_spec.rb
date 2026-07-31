# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::AppleIap::FulfillmentEvents::CreateService do
  subject(:result) { described_class.call(order:, params:) }

  let(:order) { create(:apple_iap_order) }
  let(:entitlement_id) { SecureRandom.uuid }
  let(:clone_task_id) { SecureRandom.uuid }
  let(:params) do
    {
      "event_id" => SecureRandom.uuid,
      "fulfillment_version" => 1,
      "event_type" => "clone.succeeded",
      "occurred_at" => Time.current.iso8601,
      "entitlement" => {
        "id" => entitlement_id,
        "status" => "granted"
      },
      "clone_task" => {
        "id" => clone_task_id,
        "status" => "succeeded",
        "attempt_no" => 2,
        "voice_id" => "voice-123"
      },
      "failure" => {
        "code" => "previous_attempt_failed",
        "message" => "Recovered on retry"
      },
      "payload" => {"source" => "linx-backend"}
    }
  end

  it "persists nested fulfillment attributes from JSON-style string keys" do
    expect(result).to be_success

    event = result.fulfillment_event
    expect(event).to have_attributes(
      entitlement_id:,
      entitlement_status: "granted",
      clone_task_id:,
      clone_status: "succeeded",
      attempt_no: 2,
      voice_id: "voice-123",
      failure_code: "previous_attempt_failed",
      failure_message: "Recovered on retry"
    )
    expect(order.reload).to have_attributes(
      fulfillment_status: "delivered",
      fulfillment_version: 1
    )
  end
end
