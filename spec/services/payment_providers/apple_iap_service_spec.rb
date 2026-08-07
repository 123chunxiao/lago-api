# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::AppleIapService do
  subject(:service) { described_class.new }

  let(:organization) { create(:organization) }
  let(:attributes) do
    {
      organization:,
      name: "Apple IAP",
      code: "apple-iap",
      issuer_id: SecureRandom.uuid,
      key_id: "TESTKEY123",
      private_key: OpenSSL::PKey::EC.generate("prime256v1").to_pem,
      bundle_id: "com.example.app",
      app_apple_id: 675_541_198,
      product_ids: ["pro.monthly"],
      webhook_base_url: "https://billing.example.com"
    }
  end

  it "creates an Apple IAP provider" do
    result = service.create_or_update(**attributes)

    expect(result).to be_success
    expect(result.apple_iap_provider).to have_attributes(
      code: "apple-iap",
      bundle_id: "com.example.app",
      product_ids: ["pro.monthly"],
      webhook_base_url: "https://billing.example.com"
    )
  end

  it "updates a provider without replacing its private key" do
    provider = create(:apple_iap_provider, organization:, code: "apple-iap")
    private_key = provider.private_key

    result = service.create_or_update(
      organization:,
      id: provider.id,
      name: "Updated Apple IAP",
      webhook_base_url: "https://new.example.com"
    )

    expect(result).to be_success
    expect(provider.reload).to have_attributes(
      name: "Updated Apple IAP",
      private_key:,
      webhook_base_url: "https://new.example.com"
    )
  end

  it "rejects a non-HTTPS webhook base URL" do
    result = service.create_or_update(**attributes, webhook_base_url: "http://example.com")

    expect(result).not_to be_success
    expect(result.error).to be_a(BaseService::ValidationFailure)
  end
end
