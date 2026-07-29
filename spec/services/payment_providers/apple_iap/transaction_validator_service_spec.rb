# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::AppleIap::TransactionValidatorService do
  subject(:result) do
    described_class.call(
      payload:,
      payment_provider:,
      expected_transaction_id: "2000000123456789",
      expected_product_id: "com.example.linx.voice-clone",
      expected_app_account_token: app_account_token
    )
  end

  let(:app_account_token) { SecureRandom.uuid }
  let(:payment_provider) do
    build(
      :apple_iap_provider,
      bundle_id: "com.example.linx",
      product_ids: ["com.example.linx.voice-clone"]
    )
  end
  let(:payload) do
    {
      "appAccountToken" => app_account_token,
      "bundleId" => "com.example.linx",
      "environment" => "Sandbox",
      "originalTransactionId" => "2000000123456789",
      "productId" => "com.example.linx.voice-clone",
      "purchaseDate" => 1_722_160_000_000,
      "quantity" => 1,
      "transactionId" => "2000000123456789",
      "type" => "Consumable"
    }
  end

  it "normalizes a valid consumable transaction" do
    expect(result).to be_success
    expect(result.attributes).to include(
      app_account_token:,
      environment: "sandbox",
      product_type: "Consumable",
      quantity: 1,
      transaction_id: "2000000123456789"
    )
  end

  it "rejects a transaction assigned to another app account" do
    payload["appAccountToken"] = SecureRandom.uuid

    expect(result).to be_failure
    expect(result.error.messages).to eq(
      app_account_token: ["apple_app_account_token_mismatch"]
    )
  end

  it "rejects a non-consumable product" do
    payload["type"] = "Non-Consumable"

    expect(result).to be_failure
    expect(result.error.messages).to eq(
      product_type: ["apple_product_must_be_consumable"]
    )
  end
end
