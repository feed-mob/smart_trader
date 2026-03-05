# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Seed data for assets
[
  { symbol: "BTC", name: "Bitcoin", asset_type: "crypto" },
  { symbol: "ETH", name: "Ethereum", asset_type: "crypto" },
  { symbol: "AAPL", name: "Apple Inc.", asset_type: "stock" },
  { symbol: "NVDA", name: "NVIDIA Corporation", asset_type: "stock" },
  { symbol: "GLD", name: "SPDR Gold Shares", asset_type: "commodity" }
].each do |asset_data|
  Asset.find_or_create_by!(symbol: asset_data[:symbol]) do |asset|
    asset.update!(asset_data)
  end
end
