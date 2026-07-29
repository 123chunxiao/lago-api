# frozen_string_literal: true

class CreateAppleIapOrders < ActiveRecord::Migration[8.0]
  def change
    create_enum :apple_iap_order_payment_status, %w[verifying succeeded failed]
    create_enum :apple_iap_order_refund_status, %w[none requested succeeded declined reversed manual_review]
    create_enum :apple_iap_order_fulfillment_status, %w[
      not_reported entitlement_granted processing delivered failed timed_out
    ]
    create_enum :apple_iap_notification_status, %w[pending processing succeeded failed ignored]
    create_enum :apple_iap_consumption_request_status, %w[
      awaiting_backend ready sending sent skipped_no_consent failed expired
    ]

    create_table :apple_iap_orders, id: :uuid do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.references :payment_provider,
        type: :uuid,
        null: false,
        foreign_key: {to_table: :payment_providers}

      t.uuid :business_request_id
      t.string :external_customer_id
      t.uuid :app_account_token
      t.string :transaction_id, null: false
      t.string :original_transaction_id
      t.string :product_id, null: false
      t.string :bundle_id, null: false
      t.bigint :app_apple_id
      t.string :environment, null: false
      t.string :product_type
      t.integer :quantity, null: false, default: 1
      t.bigint :price_milliunits
      t.string :currency
      t.datetime :purchased_at
      t.datetime :verified_at

      t.enum :payment_status,
        enum_type: :apple_iap_order_payment_status,
        null: false,
        default: "verifying"
      t.enum :refund_status,
        enum_type: :apple_iap_order_refund_status,
        null: false,
        default: "none"
      t.enum :fulfillment_status,
        enum_type: :apple_iap_order_fulfillment_status,
        null: false,
        default: "not_reported"

      t.integer :fulfillment_version, null: false, default: 0
      t.integer :lock_version, null: false, default: 0
      t.text :signed_transaction
      t.string :failure_code
      t.text :failure_message
      t.datetime :revocation_date
      t.string :revocation_reason
      t.integer :revocation_percentage
      t.jsonb :metadata, null: false, default: {}

      t.timestamps

      t.index [:organization_id, :business_request_id],
        unique: true,
        where: "business_request_id IS NOT NULL",
        name: "idx_apple_iap_orders_org_business_request"
      t.index [:bundle_id, :environment, :transaction_id],
        unique: true,
        name: "idx_apple_iap_orders_unique_transaction"
      t.index [:organization_id, :external_customer_id]
      t.index [:organization_id, :app_account_token]
      t.index [:organization_id, :payment_status]
      t.index [:organization_id, :refund_status]
    end

    create_table :apple_iap_notifications, id: :uuid do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.references :apple_iap_order, type: :uuid, foreign_key: true
      t.uuid :notification_uuid, null: false
      t.string :notification_type
      t.string :subtype
      t.string :environment
      t.string :transaction_id
      t.text :signed_payload, null: false
      t.enum :status,
        enum_type: :apple_iap_notification_status,
        null: false,
        default: "pending"
      t.integer :attempts, null: false, default: 0
      t.datetime :received_at, null: false
      t.datetime :processed_at
      t.text :last_error

      t.timestamps

      t.index :notification_uuid, unique: true
      t.index [:organization_id, :status]
      t.index [:organization_id, :transaction_id]
    end

    create_table :apple_iap_fulfillment_events, id: :uuid do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.references :apple_iap_order, type: :uuid, null: false, foreign_key: true
      t.uuid :event_id, null: false
      t.integer :fulfillment_version, null: false
      t.string :event_type, null: false
      t.string :entitlement_status
      t.string :clone_status
      t.uuid :entitlement_id
      t.uuid :clone_task_id
      t.string :voice_id
      t.integer :attempt_no
      t.string :failure_code
      t.text :failure_message
      t.datetime :occurred_at, null: false
      t.jsonb :payload, null: false, default: {}

      t.timestamps

      t.index :event_id, unique: true
      t.index [:apple_iap_order_id, :fulfillment_version],
        unique: true,
        name: "idx_apple_iap_fulfillment_order_version"
    end

    create_table :apple_iap_consumption_requests, id: :uuid do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.references :apple_iap_order, type: :uuid, null: false, foreign_key: true
      t.references :apple_iap_notification,
        type: :uuid,
        null: false,
        foreign_key: true,
        index: {unique: true}
      t.uuid :notification_uuid, null: false
      t.string :transaction_id, null: false
      t.datetime :deadline_at, null: false
      t.enum :status,
        enum_type: :apple_iap_consumption_request_status,
        null: false,
        default: "awaiting_backend"
      t.uuid :response_event_id
      t.jsonb :backend_snapshot, null: false, default: {}
      t.jsonb :apple_payload, null: false, default: {}
      t.integer :attempts, null: false, default: 0
      t.datetime :sent_at
      t.text :last_error

      t.timestamps

      t.index :notification_uuid, unique: true
      t.index :response_event_id, unique: true, where: "response_event_id IS NOT NULL"
      t.index [:status, :deadline_at]
    end
  end
end
