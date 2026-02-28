# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_28_033628) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "asset_snapshots", force: :cascade do |t|
    t.bigint "asset_id", null: false
    t.datetime "captured_at", null: false
    t.decimal "change_percent", precision: 8, scale: 4
    t.datetime "created_at", null: false
    t.decimal "price", precision: 15, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.decimal "volume", precision: 20
    t.index ["asset_id", "captured_at"], name: "index_asset_snapshots_on_asset_id_and_captured_at"
    t.index ["asset_id"], name: "index_asset_snapshots_on_asset_id"
    t.index ["captured_at"], name: "index_asset_snapshots_on_captured_at"
  end

  create_table "assets", force: :cascade do |t|
    t.string "asset_type", null: false
    t.datetime "created_at", null: false
    t.decimal "current_price", precision: 15, scale: 2
    t.datetime "last_updated"
    t.string "name", null: false
    t.string "symbol", null: false
    t.datetime "updated_at", null: false
    t.index ["symbol"], name: "index_assets_on_symbol", unique: true
  end

  create_table "factor_definitions", force: :cascade do |t|
    t.boolean "active", default: true
    t.string "calculation_method", null: false
    t.string "category", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.jsonb "parameters", default: {}
    t.integer "sort_order", default: 0
    t.integer "update_frequency", default: 60
    t.datetime "updated_at", null: false
    t.decimal "weight", precision: 5, scale: 4, default: "0.1"
    t.index ["active"], name: "index_factor_definitions_on_active"
    t.index ["category"], name: "index_factor_definitions_on_category"
    t.index ["code"], name: "index_factor_definitions_on_code", unique: true
  end

  create_table "factor_values", force: :cascade do |t|
    t.bigint "asset_id", null: false
    t.datetime "calculated_at", null: false
    t.datetime "created_at", null: false
    t.bigint "factor_definition_id", null: false
    t.decimal "normalized_value", precision: 10, scale: 6
    t.decimal "percentile", precision: 5, scale: 2
    t.decimal "raw_value", precision: 15, scale: 6
    t.datetime "updated_at", null: false
    t.index ["asset_id", "factor_definition_id", "calculated_at"], name: "idx_factor_values_unique", unique: true
    t.index ["asset_id"], name: "index_factor_values_on_asset_id"
    t.index ["calculated_at"], name: "index_factor_values_on_calculated_at"
    t.index ["factor_definition_id"], name: "index_factor_values_on_factor_definition_id"
  end

  create_table "traders", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "current_capital", precision: 15, scale: 2
    t.text "description"
    t.decimal "initial_capital", precision: 15, scale: 2, default: "100000.0"
    t.string "name", null: false
    t.integer "risk_level", default: 0
    t.integer "status", default: 0
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_traders_on_status"
  end

  create_table "trading_signals", force: :cascade do |t|
    t.bigint "asset_id", null: false
    t.decimal "confidence", precision: 3, scale: 2
    t.datetime "created_at", null: false
    t.jsonb "factor_snapshot", default: {}
    t.datetime "generated_at", null: false
    t.jsonb "key_factors", default: []
    t.text "reasoning"
    t.text "risk_warning"
    t.string "signal_type", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_id", "generated_at"], name: "index_trading_signals_on_asset_id_and_generated_at"
    t.index ["asset_id"], name: "index_trading_signals_on_asset_id"
    t.index ["signal_type"], name: "index_trading_signals_on_signal_type"
  end

  create_table "trading_strategies", force: :cascade do |t|
    t.decimal "buy_signal_threshold", precision: 3, scale: 2, default: "0.5"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "generated_by", default: 0
    t.integer "market_condition", default: 0, null: false
    t.decimal "max_position_size", precision: 3, scale: 2, default: "0.5"
    t.integer "max_positions", default: 3
    t.decimal "min_cash_reserve", precision: 3, scale: 2, default: "0.2"
    t.string "name", null: false
    t.integer "risk_level", default: 1
    t.bigint "trader_id", null: false
    t.datetime "updated_at", null: false
    t.index ["trader_id", "market_condition"], name: "index_trading_strategies_on_trader_id_and_market_condition", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.boolean "email_verified", default: false
    t.string "google_id"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["email", "google_id"], name: "index_users_on_email_and_google_id", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["google_id"], name: "index_users_on_google_id", unique: true
  end

  add_foreign_key "asset_snapshots", "assets"
  add_foreign_key "factor_values", "assets"
  add_foreign_key "factor_values", "factor_definitions"
  add_foreign_key "trading_signals", "assets"
  add_foreign_key "trading_strategies", "traders"
end
