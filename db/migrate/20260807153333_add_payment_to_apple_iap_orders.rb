# frozen_string_literal: true

class AddPaymentToAppleIapOrders < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_reference :apple_iap_orders,
      :payment,
      type: :uuid,
      index: {unique: true, algorithm: :concurrently}
  end
end
