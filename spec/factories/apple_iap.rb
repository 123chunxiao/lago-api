# frozen_string_literal: true

FactoryBot.define do
  factory :apple_iap_order do
    organization
    payment_provider { association(:apple_iap_provider, organization:) }
    business_request_id { SecureRandom.uuid }
    external_customer_id { SecureRandom.uuid }
    app_account_token { SecureRandom.uuid }
    sequence(:transaction_id) { |number| "200000012345#{number.to_s.rjust(4, "0")}" }
    original_transaction_id { transaction_id }
    product_id { "com.example.linx.voice-clone" }
    bundle_id { "com.example.linx" }
    app_apple_id { 123_456_789 }
    environment { "sandbox" }
    product_type { "Consumable" }
    quantity { 1 }
    payment_status { "succeeded" }
    refund_status { "none" }
    fulfillment_status { "not_reported" }
  end

  factory :apple_iap_notification do
    organization
    apple_iap_order
    notification_uuid { SecureRandom.uuid }
    notification_type { "CONSUMPTION_REQUEST" }
    environment { "sandbox" }
    transaction_id { apple_iap_order.transaction_id }
    signed_payload { "signed-payload" }
    received_at { Time.current }
  end
end
