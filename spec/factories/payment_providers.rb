# frozen_string_literal: true

FactoryBot.define do
  factory :stripe_provider, class: "PaymentProviders::StripeProvider" do
    organization
    type { "PaymentProviders::StripeProvider" }
    code { "stripe_account_#{SecureRandom.uuid}" }
    name { "Stripe Account 1" }

    secrets do
      {secret_key: SecureRandom.uuid}.to_json
    end

    settings do
      {success_redirect_url:}
    end

    transient do
      success_redirect_url { Faker::Internet.url }
    end
  end

  factory :gocardless_provider, class: "PaymentProviders::GocardlessProvider" do
    organization
    type { "PaymentProviders::GocardlessProvider" }
    code { "gocardless_account_#{SecureRandom.uuid}" }
    name { "GoCardless Account 1" }

    secrets do
      {access_token: SecureRandom.uuid}.to_json
    end

    settings do
      {success_redirect_url:}
    end

    transient do
      success_redirect_url { Faker::Internet.url }
    end
  end

  factory :adyen_provider, class: "PaymentProviders::AdyenProvider" do
    organization
    type { "PaymentProviders::AdyenProvider" }
    code { "adyen_account_#{SecureRandom.uuid}" }
    name { "Adyen Account 1" }

    secrets do
      {api_key:, hmac_key:}.to_json
    end

    settings do
      {live_prefix:, merchant_account:, success_redirect_url:}
    end

    transient do
      api_key { SecureRandom.uuid }
      merchant_account { Faker::Company.duns_number }
      live_prefix { Faker::Internet.domain_word }
      hmac_key { SecureRandom.uuid }
      success_redirect_url { Faker::Internet.url }
    end
  end

  factory :cashfree_provider, class: "PaymentProviders::CashfreeProvider" do
    organization
    type { "PaymentProviders::CashfreeProvider" }
    code { "cashfree_account_#{SecureRandom.uuid}" }
    name { "Cashfree Account 1" }

    secrets do
      {client_id: SecureRandom.uuid, client_secret: SecureRandom.uuid}.to_json
    end

    settings do
      {success_redirect_url:}
    end

    transient do
      success_redirect_url { Faker::Internet.url }
    end
  end

  factory :alipay_provider, class: "PaymentProviders::AlipayProvider" do
    organization
    type { "PaymentProviders::AlipayProvider" }
    code { "alipay_account_#{SecureRandom.uuid}" }
    name { "Alipay Account 1" }

    secrets do
      {app_id:, app_private_key:, alipay_public_key:}.to_json
    end

    settings do
      {environment:, success_redirect_url:}
    end

    transient do
      app_id { "2021000000000000" }
      app_private_key { OpenSSL::PKey::RSA.generate(2048).to_pem }
      alipay_public_key { OpenSSL::PKey::RSA.generate(2048).public_key.to_pem }
      environment { "sandbox" }
      success_redirect_url { Faker::Internet.url }
    end
  end

  factory :apple_iap_provider, class: "PaymentProviders::AppleIapProvider" do
    organization
    type { "PaymentProviders::AppleIapProvider" }
    code { "apple_iap_#{SecureRandom.uuid}" }
    name { "Apple IAP" }

    secrets do
      {issuer_id:, key_id:, private_key:}.to_json
    end

    settings do
      {bundle_id:, app_apple_id:, product_ids:}
    end

    transient do
      issuer_id { SecureRandom.uuid }
      key_id { SecureRandom.hex(5).upcase }
      private_key { OpenSSL::PKey::EC.generate("prime256v1").to_pem }
      bundle_id { "com.example.linx" }
      app_apple_id { 123_456_789 }
      product_ids { ["com.example.linx.voice-clone"] }
    end
  end

  factory :moneyhash_provider, class: "PaymentProviders::MoneyhashProvider" do
    organization
    type { "PaymentProviders::MoneyhashProvider" }
    name { "MoneyHash" }
    code { "moneyhash_#{SecureRandom.uuid}" }

    secrets do
      {api_key:}.to_json
    end

    settings do
      {success_redirect_url:, flow_id:}
    end

    transient do
      api_key { SecureRandom.uuid }
      success_redirect_url { Faker::Internet.url }
      flow_id { SecureRandom.uuid[0..19] }
    end
  end
  factory :flutterwave_provider, class: "PaymentProviders::FlutterwaveProvider" do
    organization
    type { "PaymentProviders::FlutterwaveProvider" }
    name { "Flutterwave" }
    code { "flutterwave_#{SecureRandom.uuid}" }
    secrets do
      {secret_key:, webhook_secret:}.to_json
    end

    settings do
      {success_redirect_url:}
    end

    transient do
      secret_key { "FLWSECK-#{SecureRandom.uuid}" }
      success_redirect_url { Faker::Internet.url }
      webhook_secret { SecureRandom.hex(32) }
    end
  end
end
