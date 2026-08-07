# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::AppleIap::Invoices::CreateService do
  subject(:result) { described_class.call(order:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:, external_id: "apple-customer") }
  let(:order) do
    create(
      :apple_iap_order,
      organization:,
      external_customer_id: customer.external_id,
      price_milliunits: 9990,
      currency: "USD",
      purchased_at: Time.zone.parse("2026-08-07 08:00:00")
    )
  end

  before do
    create(:tax, :applied_to_billing_entity, organization:, rate: 20)
  end

  it "creates a tax-neutral one-off invoice from the verified Apple amount" do
    expect { result }.to change(Invoice, :count).by(1).and change(AddOn, :count).by(1)

    expect(result).to be_success
    expect(result.invoice).to have_attributes(
      customer:,
      currency: "USD",
      fees_amount_cents: 999,
      taxes_amount_cents: 0,
      total_amount_cents: 999,
      payment_status: "pending",
      skip_automatic_payment: true,
      purchase_order_number: order.business_request_id.to_s
    )
    expect(result.invoice.fees.sole).to have_attributes(
      amount_cents: 999,
      taxes_amount_cents: 0,
      invoice_display_name: "Apple IAP - #{order.product_id}"
    )
  end

  context "when the Lago customer does not exist yet" do
    before do
      order.update!(external_customer_id: "missing-customer")
      customer.destroy!
    end

    it "creates a minimal customer before creating the invoice" do
      expect { result }.to change(Customer, :count).by(1).and change(Invoice, :count).by(1)

      expect(result).to be_success
      expect(result.invoice.customer).to have_attributes(
        external_id: "missing-customer",
        name: "Apple IAP customer missing-customer",
        currency: "USD"
      )
    end
  end
end
