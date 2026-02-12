# frozen_string_literal: true

# Sessions Controller - Handles user authentication
class SessionsController < ApplicationController
  # Skip CSRF protection for Google OAuth callback
  skip_before_action :verify_authenticity_token, only: :create

  # GET /login - Display login page
  def new
    @google_client_id = ENV.fetch("GOOGLE_CLIENT_ID", nil)
  end

  # POST /auth/google/callback - Handle Google Sign-In callback
  def create
    user_info = GoogleSignIn::Identity.new(params[:credential])

    # Find or create user based on Google email
    user = User.find_or_initialize_by(email: user_info.email_address)

    if user.new_record?
      # Register new user from Google account
      user.google_id = user_info.user_id
      user.name = user_info.name
      user.email_verified = true
      user.save!
    elsif user.google_id.blank?
      # Link existing account with Google
      user.update!(google_id: user_info.user_id, email_verified: true)
    end

    # Sign in the user
    session[:user_id] = user.id
    session[:user_name] = user.name

    redirect_to root_path, notice: "Welcome back, #{user.name}!"
  rescue GoogleSignIn::Identity::ValidationError => e
    redirect_to login_path, alert: "Invalid Google authentication: #{e.message}"
  rescue StandardError => e
    redirect_to login_path, alert: "Authentication failed: #{e.message}"
  end

  # DELETE /logout - Log out current user
  def destroy
    session.clear
    redirect_to login_path, notice: "You have been logged out."
  end
end
