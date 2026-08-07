# frozen_string_literal: true

module PaymentProviders
  module AppleIap
    module Invoices
      class CreateService < BaseService
        Result = BaseResult[:invoice]

        def initialize(order:)
          @order = order

          super()
        end

        def call
          return invalid_amount unless order.apple_amount_cents&.positive?

          invoice_result = ::Invoices::CreateOneOffService.call(
            customer:,
            currency: order.currency,
            fees: [
              {
                add_on_id: add_on.id,
                add_on_code: add_on.code,
                invoice_display_name: "Apple IAP - #{order.product_id}",
                unit_amount_cents: order.apple_amount_cents,
                units: order.quantity,
                description: "Apple transaction #{order.transaction_id}"
              }
            ],
            timestamp: order.purchased_at || Time.current,
            skip_psp: true,
            skip_taxes: true,
            purchase_order_number: order.business_request_id
          )
          return result.fail_with_error!(invoice_result.error) if invoice_result.failure?

          result.invoice = invoice_result.invoice
          result
        end

        private

        attr_reader :order

        def customer
          return @customer if defined?(@customer)

          order.organization.with_lock do
            @customer = order.organization.customers.find_by(external_id: order.external_customer_id) || create_customer
          end
        end

        def create_customer
          Customers::CreateService.call!(
            organization_id: order.organization_id,
            external_id: order.external_customer_id,
            name: "Apple IAP customer #{order.external_customer_id}",
            currency: order.currency
          ).customer
        end

        def add_on
          return @add_on if defined?(@add_on)

          order.organization.with_lock do
            @add_on = order.organization.add_ons.find_by(code: add_on_code) || create_add_on
          end
        end

        def create_add_on
          AddOns::CreateService.call!(
            {
              organization_id: order.organization_id,
              name: "Apple IAP - #{order.product_id}",
              invoice_display_name: "Apple IAP - #{order.product_id}",
              code: add_on_code,
              description: "Automatically generated Apple IAP invoice item",
              amount_cents: order.apple_amount_cents,
              amount_currency: order.currency
            }
          ).add_on
        end

        def add_on_code
          @add_on_code ||= "apple-iap-#{Digest::SHA256.hexdigest(order.product_id)[0, 24]}"
        end

        def invalid_amount
          result.single_validation_failure!(field: :price_milliunits, error_code: "apple_price_missing")
        end
      end
    end
  end
end
