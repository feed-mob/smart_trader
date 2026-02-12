# frozen_string_literal: true

# Home Controller - Main dashboard page after login
class HomeController < ApplicationController
  before_action :require_user

  # GET / - Main dashboard with feature navigation
  def index
    @current_user = current_user
  end

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def require_user
    redirect_to login_path, alert: "Please sign in first" unless current_user
  end
end
