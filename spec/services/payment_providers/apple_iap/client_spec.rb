# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::AppleIap::Client do
  subject(:client) { described_class.new(payment_provider:) }

  let(:payment_provider) { build(:apple_iap_provider) }
  let(:http_client) { instance_double(LagoHttpClient::Client) }

  describe "#transaction_info" do
    it "calls the App Store sandbox transaction endpoint with a signed bearer token" do
      authorization_headers = nil
      allow(LagoHttpClient::Client).to receive(:new)
        .with(
          "#{described_class::SANDBOX_BASE_URL}/inApps/v1/transactions/2000000123456789",
          retry_on_transient_errors: true
        )
        .and_return(http_client)
      allow(http_client).to receive(:get) { |headers:| authorization_headers = headers }

      client.transaction_info(transaction_id: "2000000123456789", environment: "sandbox")

      token = authorization_headers.fetch("Authorization").delete_prefix("Bearer ")
      claims, headers = JWT.decode(token, nil, false)
      expect(claims).to include(
        "iss" => payment_provider.issuer_id,
        "aud" => described_class::API_AUDIENCE,
        "bid" => payment_provider.bundle_id
      )
      expect(headers).to include(
        "alg" => "ES256",
        "kid" => payment_provider.key_id,
        "typ" => "JWT"
      )
    end
  end

  describe "#send_consumption_information" do
    it "puts consumption data to the App Store production v2 endpoint" do
      payload = {
        customerConsented: true,
        deliveryStatus: "DELIVERED",
        sampleContentProvided: false,
        consumptionPercentage: 100_000
      }
      allow(LagoHttpClient::Client).to receive(:new)
        .with(
          "#{described_class::PRODUCTION_BASE_URL}/inApps/v2/transactions/consumption/2000000123456789",
          retry_on_transient_errors: true
        )
        .and_return(http_client)
      allow(http_client).to receive(:put_with_response)

      client.send_consumption_information(
        transaction_id: "2000000123456789",
        environment: "production",
        payload:
      )

      expect(http_client).to have_received(:put_with_response).with(
        payload,
        "Authorization" => a_string_starting_with("Bearer ")
      )
    end
  end

  describe "#notification_history" do
    it "posts notification history filters with signed bearer headers" do
      payload = {
        startDate: "2026-08-01T00:00:00Z",
        endDate: "2026-08-03T00:00:00Z"
      }
      allow(LagoHttpClient::Client).to receive(:new)
        .with(
          "#{described_class::SANDBOX_BASE_URL}/inApps/v1/notifications/history",
          retry_on_transient_errors: true
        )
        .and_return(http_client)
      allow(http_client).to receive(:post)

      client.notification_history(environment: "sandbox", payload:)

      expect(http_client).to have_received(:post).with(
        payload,
        ["Authorization" => a_string_starting_with("Bearer ")]
      )
    end
  end
end
