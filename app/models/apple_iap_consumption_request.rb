# frozen_string_literal: true

class AppleIapConsumptionRequest < ApplicationRecord
  STATUSES = {
    awaiting_backend: "awaiting_backend",
    ready: "ready",
    sending: "sending",
    sent: "sent",
    skipped_no_consent: "skipped_no_consent",
    failed: "failed",
    expired: "expired"
  }.freeze

  belongs_to :organization
  belongs_to :apple_iap_order
  belongs_to :apple_iap_notification

  enum :status, STATUSES, validate: true

  validates :notification_uuid, :transaction_id, :deadline_at, presence: true
  validates :notification_uuid, uniqueness: true
  validates :response_event_id, uniqueness: true, allow_nil: true
end

# == Schema Information
#
# Table name: apple_iap_consumption_requests
# Database name: primary
#
#  id                        :uuid             not null, primary key
#  apple_payload             :jsonb            not null
#  attempts                  :integer          default(0), not null
#  backend_snapshot          :jsonb            not null
#  deadline_at               :datetime         not null
#  last_error                :text
#  notification_uuid         :uuid             not null
#  sent_at                   :datetime
#  status                    :enum             default("awaiting_backend"), not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  apple_iap_notification_id :uuid             not null
#  apple_iap_order_id        :uuid             not null
#  organization_id           :uuid             not null
#  response_event_id         :uuid
#  transaction_id            :string           not null
#
# Indexes
#
#  idx_on_apple_iap_notification_id_fd52eccb79                     (apple_iap_notification_id) UNIQUE
#  index_apple_iap_consumption_requests_on_apple_iap_order_id      (apple_iap_order_id)
#  index_apple_iap_consumption_requests_on_notification_uuid       (notification_uuid) UNIQUE
#  index_apple_iap_consumption_requests_on_organization_id         (organization_id)
#  index_apple_iap_consumption_requests_on_response_event_id       (response_event_id) UNIQUE WHERE (response_event_id IS NOT NULL)
#  index_apple_iap_consumption_requests_on_status_and_deadline_at  (status,deadline_at)
#
# Foreign Keys
#
#  fk_rails_...  (apple_iap_notification_id => apple_iap_notifications.id)
#  fk_rails_...  (apple_iap_order_id => apple_iap_orders.id)
#  fk_rails_...  (organization_id => organizations.id)
#
