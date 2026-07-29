# frozen_string_literal: true

module PaymentProviders
  module AppleIap
    class Client
      API_AUDIENCE = "appstoreconnect-v1"
      PRODUCTION_BASE_URL = "https://api.storekit.apple.com"
      SANDBOX_BASE_URL = "https://api.storekit-sandbox.apple.com"

      def initialize(payment_provider:)
        @payment_provider = payment_provider
      end

      def transaction_info(transaction_id:, environment:)
        client(
          path: "/inApps/v1/transactions/#{escaped(transaction_id)}",
          environment:
        ).get(headers: authorization_headers)
      end

      def send_consumption_information(transaction_id:, environment:, payload:)
        client(
          path: "/inApps/v2/transactions/consumption/#{escaped(transaction_id)}",
          environment:
        ).put_with_response(payload, authorization_headers)
      end

      def notification_history(environment:, payload:)
        client(
          path: "/inApps/v1/notifications/history",
          environment:
        ).post(payload, authorization_headers)
      end

      private

      attr_reader :payment_provider

      delegate :issuer_id, :key_id, :private_key, :bundle_id, to: :payment_provider

      def authorization_headers
        {"Authorization" => "Bearer #{authorization_token}"}
      end

      def authorization_token
        now = Time.current.to_i
        JWT.encode(
          {
            iss: issuer_id,
            iat: now,
            exp: now + 300,
            aud: API_AUDIENCE,
            bid: bundle_id
          },
          OpenSSL::PKey.read(private_key),
          "ES256",
          kid: key_id,
          typ: "JWT"
        )
      end

      def client(path:, environment:)
        LagoHttpClient::Client.new(
          "#{base_url(environment)}#{path}",
          retry_on_transient_errors: true
        )
      end

      def base_url(environment)
        (environment == "sandbox") ? SANDBOX_BASE_URL : PRODUCTION_BASE_URL
      end

      def escaped(value)
        CGI.escapeURIComponent(value.to_s)
      end
    end
  end
end
