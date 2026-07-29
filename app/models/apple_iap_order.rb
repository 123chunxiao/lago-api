# frozen_string_literal: true

class AppleIapOrder < ApplicationRecord
  PAYMENT_STATUSES = {
    verifying: "verifying",
    succeeded: "succeeded",
    failed: "failed"
  }.freeze
  REFUND_STATUSES = {
    none: "none",
    requested: "requested",
    succeeded: "succeeded",
    declined: "declined",
    reversed: "reversed",
    manual_review: "manual_review"
  }.freeze
  FULFILLMENT_STATUSES = {
    not_reported: "not_reported",
    entitlement_granted: "entitlement_granted",
    processing: "processing",
    delivered: "delivered",
    failed: "failed",
    timed_out: "timed_out"
  }.freeze
  ENVIRONMENTS = %w[sandbox production].freeze

  belongs_to :organization
  belongs_to :payment_provider, class_name: "PaymentProviders::AppleIapProvider"

  has_many :apple_iap_notifications
  has_many :apple_iap_fulfillment_events
  has_many :apple_iap_consumption_requests

  enum :payment_status, PAYMENT_STATUSES, prefix: :payment, validate: true
  enum :refund_status, REFUND_STATUSES, prefix: :refund, validate: true
  enum :fulfillment_status, FULFILLMENT_STATUSES, prefix: :fulfillment, validate: true

  validates :business_request_id, :transaction_id, :product_id, :bundle_id, presence: true
  validates :environment, inclusion: {in: ENVIRONMENTS}
  validates :quantity, numericality: {only_integer: true, equal_to: 1}
  validates :business_request_id, uniqueness: {scope: :organization_id}, allow_nil: true
  validates :transaction_id, uniqueness: {scope: %i[bundle_id environment]}

  def self.ransackable_attributes(_auth_object = nil)
    %w[id business_request_id external_customer_id transaction_id product_id payment_status refund_status]
  end
end

# == Schema Information
#
# Table name: apple_iap_orders
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  app_account_token       :uuid
#  currency                :string
#  environment             :string           not null
#  failure_code            :string
#  failure_message         :text
#  fulfillment_status      :enum             default("not_reported"), not null
#  fulfillment_version     :integer          default(0), not null
#  lock_version            :integer          default(0), not null
#  metadata                :jsonb            not null
#  payment_status          :enum             default("verifying"), not null
#  price_milliunits        :bigint
#  product_type            :string
#  purchased_at            :datetime
#  quantity                :integer          default(1), not null
#  refund_status           :enum             default("none"), not null
#  revocation_date         :datetime
#  revocation_percentage   :integer
#  revocation_reason       :string
#  signed_transaction      :text
#  verified_at             :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  app_apple_id            :bigint
#  bundle_id               :string           not null
#  business_request_id     :uuid
#  external_customer_id    :string
#  organization_id         :uuid             not null
#  original_transaction_id :string
#  payment_provider_id     :uuid             not null
#  product_id              :string           not null
#  transaction_id          :string           not null
#
# Indexes
#
#  idx_apple_iap_orders_org_business_request                     (organization_id,business_request_id) UNIQUE WHERE (business_request_id IS NOT NULL)
#  idx_apple_iap_orders_unique_transaction                       (bundle_id,environment,transaction_id) UNIQUE
#  idx_on_organization_id_app_account_token_9aff424526           (organization_id,app_account_token)
#  idx_on_organization_id_external_customer_id_83989a0b8c        (organization_id,external_customer_id)
#  index_apple_iap_orders_on_organization_id                     (organization_id)
#  index_apple_iap_orders_on_organization_id_and_payment_status  (organization_id,payment_status)
#  index_apple_iap_orders_on_organization_id_and_refund_status   (organization_id,refund_status)
#  index_apple_iap_orders_on_payment_provider_id                 (payment_provider_id)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (payment_provider_id => payment_providers.id)
#
