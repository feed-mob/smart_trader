# frozen_string_literal: true

# User - Represents a SmartTrader user
class User < ApplicationRecord
  # Associations
  has_many :traders, dependent: :destroy

  # Validations
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, allow_nil: true

  # Scopes
  scope :verified, -> { where(email_verified: true) }

  # Check if user is logged in via Google
  def google_authenticated?
    google_id.present?
  end

  # Display name for UI
  def display_name
    name.presence || email.split("@").first
  end
end
