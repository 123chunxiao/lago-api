# frozen_string_literal: true

module PaymentProviders
  module AppleIap
    module ConsumptionRequests
      class RespondService < BaseService
        DELIVERY_STATUSES = %w[
          DELIVERED UNDELIVERED_QUALITY_ISSUE UNDELIVERED_SERVER_OUTAGE UNDELIVERED_OTHER
        ].freeze
        REFUND_PREFERENCES = %w[GRANT_FULL DECLINE].freeze
        Result = BaseResult[:consumption_request]

        def initialize(consumption_request:, params:)
          @consumption_request = consumption_request
          @params = params

          super()
        end

        def call
          existing_response = consumption_request.response_event_id.present?
          if existing_response
            unless consumption_request.response_event_id == params[:response_event_id]
              return result.single_validation_failure!(
                field: :response_event_id,
                error_code: "consumption_response_conflict"
              )
            end

            result.consumption_request = consumption_request
            return result
          end

          validation_error = validate_payload
          return validation_error if validation_error

          consumption_request.with_lock do
            consumption_request.update!(
              response_event_id: params[:response_event_id],
              backend_snapshot: params[:backend_snapshot] || {},
              apple_payload: apple_payload,
              status: params[:customer_consented] ? :ready : :skipped_no_consent
            )
          end
          if params[:customer_consented]
            after_commit { SendJob.perform_later(consumption_request) }
          end
          result.consumption_request = consumption_request
          result
        rescue ActiveRecord::RecordInvalid => e
          result.record_validation_failure!(record: e.record)
        end

        private

        attr_reader :consumption_request, :params

        def validate_payload
          return invalid(:response_event_id, "response_event_id_missing") if params[:response_event_id].blank?
          return invalid(:customer_consented, "customer_consent_missing") if params[:customer_consented].nil?
          return unless params[:customer_consented]
          unless DELIVERY_STATUSES.include?(params[:delivery_status])
            return invalid(:delivery_status, "invalid_delivery_status")
          end
          if params[:sample_content_provided].nil?
            return invalid(:sample_content_provided, "sample_content_provided_missing")
          end
          return invalid(:consumption_percentage, "invalid_consumption_percentage") unless valid_percentage?
          if params[:refund_preference].present? && !REFUND_PREFERENCES.include?(params[:refund_preference])
            return invalid(:refund_preference, "invalid_refund_preference")
          end

          if params[:delivery_status] != "DELIVERED" && params[:consumption_percentage].to_i != 0
            return invalid(:consumption_percentage, "undelivered_consumption_must_be_zero")
          end

          nil
        end

        def valid_percentage?
          return false unless params[:consumption_percentage].to_s.match?(/\A\d+\z/)

          params[:consumption_percentage].to_i.between?(0, 100_000)
        end

        def apple_payload
          return {} unless params[:customer_consented]

          {
            customerConsented: true,
            deliveryStatus: params[:delivery_status],
            sampleContentProvided: params[:sample_content_provided],
            consumptionPercentage: params[:consumption_percentage].to_i,
            refundPreference: params[:refund_preference]
          }.compact
        end

        def invalid(field, code)
          result.single_validation_failure!(field:, error_code: code)
        end
      end
    end
  end
end
