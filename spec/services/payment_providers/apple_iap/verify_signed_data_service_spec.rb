# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::AppleIap::VerifySignedDataService do
  subject(:result) do
    described_class.call(
      signed_data:,
      root_certificates: [root_certificate]
    )
  end

  let(:root_key) { OpenSSL::PKey::EC.generate("prime256v1") }
  let(:leaf_key) { OpenSSL::PKey::EC.generate("prime256v1") }
  let(:root_certificate) { certificate(subject: "/CN=Test Root", key: root_key, ca: true) }
  let(:leaf_certificate) do
    certificate(
      subject: "/CN=Test Leaf",
      key: leaf_key,
      issuer_certificate: root_certificate,
      issuer_key: root_key
    )
  end
  let(:payload) { {"transactionId" => "2000000123456789"} }
  let(:signed_data) do
    JWT.encode(
      payload,
      leaf_key,
      "ES256",
      x5c: [
        Base64.strict_encode64(leaf_certificate.to_der),
        Base64.strict_encode64(root_certificate.to_der)
      ]
    )
  end

  it "verifies ES256 and a certificate chain anchored to the pinned root" do
    expect(result).to be_success
    expect(result.payload).to eq(payload)
  end

  it "rejects a certificate chain anchored to another root" do
    other_key = OpenSSL::PKey::EC.generate("prime256v1")
    other_root = certificate(subject: "/CN=Other Root", key: other_key, ca: true)

    failed_result = described_class.call(
      signed_data:,
      root_certificates: [other_root]
    )

    expect(failed_result).to be_failure
    expect(failed_result.error.messages[:signed_data].first)
      .to include("certificate chain is not trusted")
  end

  def certificate(subject:, key:, ca: false, issuer_certificate: nil, issuer_key: nil)
    certificate = OpenSSL::X509::Certificate.new
    certificate.version = 2
    certificate.serial = SecureRandom.random_number(1_000_000)
    certificate.subject = OpenSSL::X509::Name.parse(subject)
    certificate.issuer = issuer_certificate&.subject || certificate.subject
    certificate.public_key = key
    certificate.not_before = 1.minute.ago
    certificate.not_after = 1.hour.from_now

    extension_factory = OpenSSL::X509::ExtensionFactory.new
    extension_factory.subject_certificate = certificate
    extension_factory.issuer_certificate = issuer_certificate || certificate
    certificate.add_extension(
      extension_factory.create_extension(
        "basicConstraints",
        ca ? "critical,CA:TRUE" : "critical,CA:FALSE"
      )
    )
    certificate.add_extension(
      extension_factory.create_extension(
        "keyUsage",
        ca ? "critical,keyCertSign,cRLSign" : "critical,digitalSignature"
      )
    )
    certificate.sign(issuer_key || key, OpenSSL::Digest.new("SHA256"))
    certificate
  end
end
