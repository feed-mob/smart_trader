class Asset < ApplicationRecord
  has_many :snapshots, class_name: "AssetSnapshot", dependent: :destroy

  validates :symbol, presence: true, uniqueness: true
  validates :name, presence: true
  validates :asset_type, presence: true, inclusion: { in: ["crypto", "stock", "commodity"] }
  validates :current_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  def latest_snapshot
    snapshots.order(captured_at: :desc).first
  end
end
