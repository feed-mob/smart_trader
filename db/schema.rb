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

ActiveRecord::Schema[8.1].define(version: 2026_02_24_085906) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "trading_strategies", force: :cascade do |t|
    t.decimal "buy_signal_threshold", precision: 3, scale: 2, default: "0.5"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "generated_by", default: 0
    t.decimal "max_position_size", precision: 3, scale: 2, default: "0.5"
    t.integer "max_positions", default: 3
    t.decimal "min_cash_reserve", precision: 3, scale: 2, default: "0.2"
    t.string "name", null: false
    t.integer "risk_level", default: 1
    t.bigint "trader_id", null: false
    t.datetime "updated_at", null: false
    t.index ["trader_id"], name: "index_trading_strategies_on_trader_id", unique: true
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

  add_foreign_key "trading_strategies", "traders"
end
