# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::AppleIap::Payments::UpsertService do
  subject(:result) { described_class.call(order:, invoice_id:, create_invoice:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:, external_id: "apple-customer") }
  let(:provider) { create(:apple_iap_provider, organization:) }
  let(:invoice) do
    create(
      :invoice,
      organization:,
      customer:,
      status: :finalized,
      currency: "USD",
      total_amount_cents: 999,
      total_paid_amount_cents: 0
    )
  end
  let(:invoice_id) { invoice.id }
  let(:create_invoice) { false }
  let(:order) do
    create(
      :apple_iap_order,
      organization:,
      payment_provider: provider,
      external_customer_id: customer.external_id,
      price_milliunits: 9990,
      currency: "USD",
      payment_status: :verifying
    )
  end

  it "creates a processing payment linked to the invoice" do
    expect { result }.to change(Payment, :count).by(1)

    expect(result).to be_success
    expect(order.reload.payment).to have_attributes(
      payable: invoice,
      customer:,
      payment_provider: provider,
      provider_payment_id: order.transaction_id,
      amount_cents: 999,
      amount_currency: "USD",
      payable_payment_status: "processing"
    )
    expect(invoice.reload).to have_attributes(payment_status: "pending", payment_attempts: 1)
  end

  it "updates the same payment and settles the invoice after verification" do
    first_result = result
    order.update!(payment_status: :succeeded)

    expect { described_class.call(order:) }.not_to change(Payment, :count)

    expect(first_result.payment.reload).to have_attributes(
      status: "succeeded",
      payable_payment_status: "succeeded"
    )
    expect(invoice.reload).to have_attributes(
      payment_status: "succeeded",
      total_paid_amount_cents: 999,
      payment_attempts: 1
    )
  end

  context "when the invoice customer does not match" do
    let(:customer) { create(:customer, organization:, external_id: "invoice-customer") }

    before do
      order.update!(external_customer_id: "another-customer")
    end

    it "rejects the invoice" do
      expect(result).not_to be_success
      expect(result.error.messages).to eq(external_customer_id: ["invoice_customer_mismatch"])
      expect(order.reload.payment).to be_nil
    end
  end

  context "without an invoice id" do
    let(:invoice_id) { nil }

    it "keeps the existing standalone IAP flow" do
      expect(result).to be_success
      expect(result.payment).to be_nil
      expect(order.reload.payment).to be_nil
    end
  end

  context "when automatic invoice creation is requested" do
    let(:invoice_id) { nil }
    let(:create_invoice) { true }

    before do
      order.update!(payment_status: :succeeded)
    end

    it "creates and settles a one-off invoice" do
      expect { result }.to change(Invoice, :count).by(1).and change(Payment, :count).by(1)

      expect(result).to be_success
      expect(result.invoice).to have_attributes(
        customer:,
        currency: "USD",
        total_amount_cents: 999,
        total_paid_amount_cents: 999,
        payment_status: "succeeded",
        skip_automatic_payment: true
      )
      expect(order.reload.payment).to eq(result.payment)
    end
  end

  context "when the Apple amount does not match the invoice" do
    before do
      order.update!(price_milliunits: 1990)
    end

    it "rejects the invoice" do
      expect(result).not_to be_success
      expect(result.error.messages).to eq(price_milliunits: ["apple_invoice_amount_mismatch"])
      expect(order.reload.payment).to be_nil
    end
  end
end
