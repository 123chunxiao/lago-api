# frozen_string_literal: true

module Api
  module V1
    module PaymentProviders
      class AppleIapController < Api::BaseController
        def update
          upsert_result = ::PaymentProviders::AppleIap::UpsertService.call(
            organization: current_organization,
            code: params[:code],
            params: input_params.to_h.symbolize_keys
          )

          if upsert_result.success?
            render(
              json: ::V1::PaymentProviders::AppleIapSerializer.new(
                upsert_result.payment_provider,
                root_name: "payment_provider"
              )
            )
          else
            render_error_response(upsert_result)
          end
        end

        private

        def input_params
          params.require(:payment_provider).permit(
            :name,
            :issuer_id,
            :key_id,
            :private_key,
            :bundle_id,
            :app_apple_id,
            product_ids: []
          )
        end

        def resource_name
          "payment_provider"
        end
      end
    end
  end
end
