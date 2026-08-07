# frozen_string_literal: true

module Mutations
  module PaymentProviders
    module AppleIap
      class Base < BaseMutation
        include AuthenticableApiUser
        include RequiredOrganization

        def resolve(**args)
          result = ::PaymentProviders::AppleIapService
            .new
            .create_or_update(**args.merge(organization: current_organization))

          result.success? ? result.apple_iap_provider : result_error(result)
        end
      end
    end
  end
end
