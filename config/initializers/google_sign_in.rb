# Google Sign-In Configuration
# Reference: /Users/jason/rails/feedmob-product-hub/config/initializers/google_sign_in.rb
Rails.application.configure do
  config.google_sign_in.client_id = ENV.fetch("OAUTH_GOOGLE_CLIENT_ID", nil)
  config.google_sign_in.client_secret = ENV.fetch("OAUTH_GOOGLE_CLIENT_SECRET", nil)
end
