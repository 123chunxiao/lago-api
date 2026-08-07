# frozen_string_literal: true

module V1
  class AppleIapOrderSerializer < ModelSerializer
    def serialize
      {
        lago_id: model.id,
        business_request_id: model.business_request_id,
        lago_payment_id: model.payment_id,
        lago_invoice_id: (model.payment&.payable_type == "Invoice") ? model.payment.payable_id : nil,
        external_customer_id: model.external_customer_id,
        app_account_token: model.app_account_token,
        transaction_id: model.transaction_id,
        original_transaction_id: model.original_transaction_id,
        product_id: model.product_id,
        environment: model.environment,
        quantity: model.quantity,
        price_milliunits: model.price_milliunits,
        currency: model.currency,
        purchased_at: model.purchased_at&.iso8601,
        verified_at: model.verified_at&.iso8601,
        payment_status: model.payment_status,
        refund_status: model.refund_status,
        fulfillment_status: model.fulfillment_status,
        fulfillment_version: model.fulfillment_version,
        failure_code: model.failure_code,
        failure_message: model.failure_message,
        created_at: model.created_at.iso8601,
        updated_at: model.updated_at.iso8601
      }
    end
  end
end
