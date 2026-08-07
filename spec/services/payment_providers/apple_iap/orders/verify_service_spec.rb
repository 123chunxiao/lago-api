# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::AppleIap::Orders::VerifyService do
  subject(:result) { described_class.call(organization:, params:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:, external_id: "apple-customer") }
  let(:provider) { create(:apple_iap_provider, organization:, code: "apple-iap") }
  let(:order) do
    create(
      :apple_iap_order,
      organization:,
      payment_provider: provider,
      external_customer_id: customer.external_id,
      price_milliunits: 9990,
      currency: "USD",
      payment_status: :succeeded,
      metadata: {}
    )
  end
  let(:params) do
    {
      business_request_id: order.business_request_id,
      external_customer_id: order.external_customer_id,
      app_account_token: order.app_account_token,
      transaction_id: order.transaction_id,
      product_id: order.product_id,
      signed_transaction: "signed-transaction",
      payment_provider_code: provider.code,
      create_invoice: true
    }
  end

  it "backfills one idempotent invoice and payment for a verified standalone order" do
    expect { result }.to change(Invoice, :count).by(1).and change(Payment, :count).by(1)

    expect(result).to be_success
    expect(order.reload).to have_attributes(
      payment: result.apple_iap_order.payment,
      metadata: {"create_invoice" => true}
    )

    invoice_count = Invoice.count
    payment_count = Payment.count
    retry_result = described_class.call(organization:, params:)

    expect(retry_result).to be_success
    expect(Invoice.count).to eq(invoice_count)
    expect(Payment.count).to eq(payment_count)
  end

  context "when create_invoice is not a JSON boolean" do
    before do
      params[:create_invoice] = "true"
    end

    it "rejects the request" do
      expect(result).not_to be_success
      expect(result.error.messages).to eq(create_invoice: ["invalid_boolean"])
    end
  end
end
