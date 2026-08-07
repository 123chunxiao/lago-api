# frozen_string_literal: true

module PaymentProviders
  module AppleIap
    module Payments
      class UpsertService < BaseService
        Result = BaseResult[:payment, :invoice]

        def initialize(order:, invoice_id: nil, create_invoice: false)
          @order = order
          @invoice_id = invoice_id
          @create_invoice = create_invoice

          super()
        end

        def call
          return result unless invoice_id.present? || create_invoice || order.payment.present?

          ActiveRecord::Base.transaction do
            order.with_lock do
              @payment = nil
              @invoice = find_invoice
              return result.not_found_failure!(resource: "invoice") unless invoice

              invoice.with_lock do
                validation_error = validate_invoice
                return validation_error if validation_error

                upsert_payment
                update_invoice
              end
            end
          end

          result.payment = payment
          result.invoice = invoice
          result
        rescue ActiveRecord::RecordInvalid => e
          result.record_validation_failure!(record: e.record)
        end

        private

        attr_reader :order, :invoice_id, :invoice, :create_invoice

        def find_invoice
          if order.payment.present?
            return order.payment.payable if order.payment.payable_type == "Invoice"

            return
          end

          return order.organization.invoices.find_by(id: invoice_id) if invoice_id.present?

          return unless create_invoice && order.payment_succeeded?

          invoice_result = PaymentProviders::AppleIap::Invoices::CreateService.call(order:)
          invoice_result.raise_if_error!
          invoice_result.invoice
        end

        def validate_invoice
          return invalid(:lago_invoice_id, "invoice_is_not_payable") unless payable_invoice?
          return invalid(:external_customer_id, "invoice_customer_mismatch") unless customer_matches?
          return invalid(:currency, "apple_invoice_currency_mismatch") unless currency_matches?
          return invalid(:price_milliunits, "apple_price_missing") if apple_amount_cents.nil?

          if payment.nil? && invoice.total_due_amount_cents != apple_amount_cents
            return invalid(:price_milliunits, "apple_invoice_amount_mismatch")
          end

          nil
        end

        def payable_invoice?
          Invoice::MANUALLY_PAYABLE_INVOICE_STATUS.include?(invoice.status.to_sym) ||
            order.payment.present?
        end

        def customer_matches?
          invoice.customer.external_id == order.external_customer_id
        end

        def currency_matches?
          invoice.currency.casecmp?(order.currency.to_s)
        end

        def apple_amount_cents
          return @apple_amount_cents if defined?(@apple_amount_cents)
          return @apple_amount_cents = nil if order.price_milliunits.blank? || order.currency.blank?

          @apple_amount_cents = order.apple_amount_cents
        end

        def payment
          @payment ||= order.payment || order.payment_provider.payments.find_by(
            provider_payment_id: order.transaction_id
          )
        end

        def upsert_payment
          new_payment = payment.nil?
          @payment ||= invoice.payments.build(
            organization: order.organization,
            customer: invoice.customer,
            payment_provider: order.payment_provider,
            payment_type: :provider,
            provider_payment_id: order.transaction_id,
            amount_cents: apple_amount_cents,
            amount_currency: order.currency,
            provider_payment_method_data: {}
          )

          unless payment.payable == invoice
            return invalid(:lago_invoice_id, "apple_transaction_invoice_conflict").raise_if_error!
          end

          @payment_was_succeeded = payment.payable_payment_status == "succeeded"
          payment.assign_attributes(
            status: order.payment_status,
            payable_payment_status: payable_payment_status,
            provider_payment_data: provider_payment_data
          )
          payment.save!
          order.update!(payment:) unless order.payment == payment
          invoice.update!(payment_attempts: invoice.payment_attempts + 1) if new_payment
        end

        def update_invoice
          total_paid_amount_cents = invoice.payments
            .where(payable_payment_status: :succeeded)
            .sum(:amount_cents)
          settled_amount_cents = total_paid_amount_cents + invoice.offset_amount_cents
          invoice_payment_status = if settled_amount_cents >= invoice.total_amount_cents
            :succeeded
          elsif payable_payment_status == :failed
            :failed
          else
            :pending
          end

          ::Invoices::UpdateService.call!(
            invoice:,
            params: {
              payment_status: invoice_payment_status,
              ready_for_payment_processing: invoice_payment_status != :succeeded,
              total_paid_amount_cents:
            },
            webhook_notification: true
          )

          if payable_payment_status == :succeeded && !@payment_was_succeeded
            after_commit { SendWebhookJob.perform_later("payment.succeeded", payment) }
          end
        end

        def payable_payment_status
          case order.payment_status
          when "verifying" then :processing
          when "succeeded" then :succeeded
          when "failed" then :failed
          end
        end

        def provider_payment_data
          {
            product_id: order.product_id,
            original_transaction_id: order.original_transaction_id,
            environment: order.environment,
            app_account_token: order.app_account_token
          }.compact
        end

        def invalid(field, code)
          result.single_validation_failure!(field:, error_code: code)
        end
      end
    end
  end
end
