class AddMarketCapToAssets < ActiveRecord::Migration[8.1]
  def change
    add_column :assets, :market_cap, :decimal
    add_column :assets, :market_cap_rank, :integer
  end
end
