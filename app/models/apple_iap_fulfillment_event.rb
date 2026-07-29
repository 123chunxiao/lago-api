# frozen_string_literal: true

class AppleIapFulfillmentEvent < ApplicationRecord
  EVENT_TYPES = %w[
    entitlement.granted
    entitlement.reserved
    clone.started
    clone.succeeded
    clone.failed
    clone.timed_out
    entitlement.restored
    entitlement.revoked
  ].freeze

  belongs_to :organization
  belongs_to :apple_iap_order

  validates :event_id, :fulfillment_version, :event_type, :occurred_at, presence: true
  validates :event_id, uniqueness: true
  validates :event_type, inclusion: {in: EVENT_TYPES}
  validates :fulfillment_version,
    numericality: {only_integer: true, greater_than: 0},
    uniqueness: {scope: :apple_iap_order_id}
end

# == Schema Information
#
# Table name: apple_iap_fulfillment_events
# Database name: primary
#
#  id                  :uuid             not null, primary key
#  attempt_no          :integer
#  clone_status        :string
#  entitlement_status  :string
#  event_type          :string           not null
#  failure_code        :string
#  failure_message     :text
#  fulfillment_version :integer          not null
#  occurred_at         :datetime         not null
#  payload             :jsonb            not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  apple_iap_order_id  :uuid             not null
#  clone_task_id       :uuid
#  entitlement_id      :uuid
#  event_id            :uuid             not null
#  organization_id     :uuid             not null
#  voice_id            :string
#
# Indexes
#
#  idx_apple_iap_fulfillment_order_version                   (apple_iap_order_id,fulfillment_version) UNIQUE
#  index_apple_iap_fulfillment_events_on_apple_iap_order_id  (apple_iap_order_id)
#  index_apple_iap_fulfillment_events_on_event_id            (event_id) UNIQUE
#  index_apple_iap_fulfillment_events_on_organization_id     (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (apple_iap_order_id => apple_iap_orders.id)
#  fk_rails_...  (organization_id => organizations.id)
#
