# frozen_string_literal: true

class AppleIapNotification < ApplicationRecord
  STATUSES = {
    pending: "pending",
    processing: "processing",
    succeeded: "succeeded",
    failed: "failed",
    ignored: "ignored"
  }.freeze

  belongs_to :organization
  belongs_to :apple_iap_order, optional: true

  enum :status, STATUSES, validate: true, prefix: true

  validates :notification_uuid, :signed_payload, :received_at, presence: true
  validates :notification_uuid, uniqueness: true
end

# == Schema Information
#
# Table name: apple_iap_notifications
# Database name: primary
#
#  id                 :uuid             not null, primary key
#  attempts           :integer          default(0), not null
#  environment        :string
#  last_error         :text
#  notification_type  :string
#  notification_uuid  :uuid             not null
#  processed_at       :datetime
#  received_at        :datetime         not null
#  signed_payload     :text             not null
#  status             :enum             default("pending"), not null
#  subtype            :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  apple_iap_order_id :uuid
#  organization_id    :uuid             not null
#  transaction_id     :string
#
# Indexes
#
#  idx_on_organization_id_transaction_id_529085d797             (organization_id,transaction_id)
#  index_apple_iap_notifications_on_apple_iap_order_id          (apple_iap_order_id)
#  index_apple_iap_notifications_on_notification_uuid           (notification_uuid) UNIQUE
#  index_apple_iap_notifications_on_organization_id             (organization_id)
#  index_apple_iap_notifications_on_organization_id_and_status  (organization_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (apple_iap_order_id => apple_iap_orders.id)
#  fk_rails_...  (organization_id => organizations.id)
#
