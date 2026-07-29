# frozen_string_literal: true

module PaymentProviders
  module AppleIap
    class VerifySignedDataService < BaseService
      Result = BaseResult[:payload]

      def initialize(signed_data:, root_certificates: nil)
        @signed_data = signed_data
        @root_certificates = root_certificates

        super()
      end

      def call
        header = JWT.decode(signed_data, nil, false).last
        certificates = certificates_from(header)
        return invalid_signed_data("Apple signed data must use ES256") unless header["alg"] == "ES256"
        return invalid_signed_data("Apple signed data certificate chain is missing") if certificates.empty?
        return invalid_signed_data("Apple signed data certificate chain is not trusted") unless trusted?(certificates)

        result.payload = JWT.decode(
          signed_data,
          certificates.first.public_key,
          true,
          algorithm: "ES256"
        ).first
        result
      rescue JWT::DecodeError, OpenSSL::OpenSSLError, ArgumentError, TypeError => e
        invalid_signed_data(e.message)
      end

      private

      attr_reader :signed_data, :root_certificates

      def certificates_from(header)
        Array(header["x5c"]).map do |certificate|
          OpenSSL::X509::Certificate.new(Base64.strict_decode64(certificate))
        end
      end

      def trusted?(certificates)
        return false if trusted_roots.empty?

        store = OpenSSL::X509::Store.new
        trusted_roots.each { |certificate| store.add_cert(certificate) }
        store.verify(certificates.first, certificates.drop(1))
      end

      def trusted_roots
        @trusted_roots ||= root_certificates || configured_root_certificates
      end

      def configured_root_certificates
        ENV.fetch("APPLE_ROOT_CA_PATHS", "")
          .split(",")
          .filter_map { |path| certificate_from_path(path.strip) if path.present? }
      end

      def certificate_from_path(path)
        OpenSSL::X509::Certificate.new(File.binread(path))
      end

      def invalid_signed_data(message)
        result.single_validation_failure!(
          field: :signed_data,
          error_code: "invalid_apple_signed_data: #{message}"
        )
      end
    end
  end
end
