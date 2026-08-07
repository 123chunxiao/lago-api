# frozen_string_literal: true

class AddAppleIapOrdersPaymentForeignKey < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key :apple_iap_orders, :payments, validate: false
  end
end
