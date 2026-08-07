# frozen_string_literal: true

class ValidateAppleIapOrdersPaymentForeignKey < ActiveRecord::Migration[8.0]
  def change
    validate_foreign_key :apple_iap_orders, :payments
  end
end
