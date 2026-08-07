# frozen_string_literal: true

module PaymentProviders
  class AppleIapProvider < BaseProvider
    PROCESSING_STATUSES = %w[verifying].freeze
    SUCCESS_STATUSES = %w[succeeded].freeze
    FAILED_STATUSES = %w[failed].freeze

    secrets_accessors :issuer_id, :key_id, :private_key
    settings_accessors :bundle_id, :app_apple_id, :product_ids, :webhook_base_url

    validates :issuer_id, :key_id, :private_key, :bundle_id, :app_apple_id, presence: true
    validates :app_apple_id, numericality: {only_integer: true, greater_than: 0}
    validates :product_ids, presence: true
    validate :product_ids_are_strings
    validate :webhook_base_url_is_https

    def payment_type
      "apple_iap"
    end

    private

    def product_ids_are_strings
      valid_product_ids = product_ids.is_a?(Array) &&
        product_ids.present? &&
        product_ids.all? do |product_id|
          product_id.is_a?(String) && product_id.present?
        end
      return if valid_product_ids

      errors.add(:product_ids, :invalid)
    end

    def webhook_base_url_is_https
      return if webhook_base_url.blank?

      uri = URI.parse(webhook_base_url)
      return if uri.is_a?(URI::HTTPS) && uri.host.present? && uri.path.in?(["", "/"])

      errors.add(:webhook_base_url, :invalid)
    rescue URI::InvalidURIError
      errors.add(:webhook_base_url, :invalid)
    end
  end
end

# == Schema Information
#
# Table name: payment_providers
# Database name: primary
#
#  id              :uuid             not null, primary key
#  code            :string           not null
#  deleted_at      :datetime
#  name            :string           not null
#  secrets         :string
#  settings        :jsonb            not null
#  type            :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :uuid             not null
#
# Indexes
#
#  index_payment_providers_on_code_and_organization_id  (code,organization_id) UNIQUE WHERE (deleted_at IS NULL)
#  index_payment_providers_on_organization_id           (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#
