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

ActiveRecord::Schema[8.1].define(version: 2026_03_18_141629) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "allocation_decisions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "decision_date", null: false
    t.text "error_message"
    t.datetime "generated_at"
    t.string "llm_model_name"
    t.text "market_analysis"
    t.jsonb "recommendation_payload", default: {}, null: false
    t.string "selected_strategy"
    t.string "source", default: "llm", null: false
    t.integer "status", default: 0, null: false
    t.text "summary"
    t.bigint "trader_id", null: false
    t.bigint "trading_strategy_id"
    t.datetime "updated_at", null: false
    t.integer "validation_status", default: 0, null: false
    t.index ["status"], name: "index_allocation_decisions_on_status"
    t.index ["trader_id", "decision_date"], name: "index_allocation_decisions_on_trader_id_and_decision_date"
    t.index ["trader_id"], name: "index_allocation_decisions_on_trader_id"
    t.index ["trading_strategy_id"], name: "index_allocation_decisions_on_trading_strategy_id"
  end

  create_table "allocation_tasks", force: :cascade do |t|
    t.bigint "allocation_decision_id"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.decimal "ending_cash", precision: 15, scale: 2, default: "0.0", null: false
    t.text "error_message"
    t.jsonb "execution_payload", default: {}, null: false
    t.decimal "portfolio_value", precision: 15, scale: 2, default: "0.0", null: false
    t.date "run_on", null: false
    t.datetime "started_at"
    t.decimal "starting_cash", precision: 15, scale: 2, default: "0.0", null: false
    t.integer "status", default: 0, null: false
    t.text "summary"
    t.bigint "trader_id", null: false
    t.datetime "updated_at", null: false
    t.index ["allocation_decision_id"], name: "index_allocation_tasks_on_allocation_decision_id"
    t.index ["status"], name: "index_allocation_tasks_on_status"
    t.index ["trader_id", "run_on"], name: "index_allocation_tasks_on_trader_id_and_run_on"
    t.index ["trader_id"], name: "index_allocation_tasks_on_trader_id"
  end

  create_table "asset_snapshots", force: :cascade do |t|
    t.bigint "asset_id", null: false
    t.datetime "captured_at", null: false
    t.decimal "change_percent", precision: 8, scale: 4
    t.datetime "created_at", null: false
    t.decimal "price", precision: 15, scale: 2, null: false
    t.date "snapshot_date", null: false
    t.datetime "updated_at", null: false
    t.decimal "volume", precision: 20, scale: 2
    t.index ["asset_id", "snapshot_date"], name: "index_asset_snapshots_on_asset_id_and_snapshot_date", unique: true
    t.index ["captured_at"], name: "index_asset_snapshots_on_captured_at"
    t.index ["snapshot_date"], name: "index_asset_snapshots_on_snapshot_date"
  end

  create_table "assets", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "asset_type", null: false
    t.string "coingecko_id"
    t.datetime "created_at", null: false
    t.decimal "current_price", precision: 15, scale: 2
    t.string "exchange", default: "UNKNOWN", null: false
    t.datetime "last_updated"
    t.decimal "market_cap"
    t.integer "market_cap_rank"
    t.string "name", null: false
    t.string "quote_currency", default: "USD", null: false
    t.string "symbol", null: false
    t.datetime "updated_at", null: false
    t.string "yahoo_symbol"
    t.index ["active"], name: "index_assets_on_active"
    t.index ["asset_type"], name: "index_assets_on_asset_type"
    t.index ["coingecko_id"], name: "index_assets_on_coingecko_id", unique: true
    t.index ["symbol", "exchange", "quote_currency"], name: "index_assets_on_symbol_and_exchange_and_quote_currency", unique: true
    t.index ["yahoo_symbol"], name: "index_assets_on_yahoo_symbol", unique: true
  end

  create_table "candles", force: :cascade do |t|
    t.bigint "asset_id", null: false
    t.datetime "candle_time", null: false
    t.decimal "close_price", precision: 15, scale: 2, null: false
    t.datetime "created_at", null: false
    t.decimal "high_price", precision: 15, scale: 2, null: false
    t.string "interval", default: "4h", null: false
    t.decimal "low_price", precision: 15, scale: 2, null: false
    t.decimal "open_price", precision: 15, scale: 2, null: false
    t.decimal "quote_volume", precision: 20, scale: 2
    t.datetime "updated_at", null: false
    t.decimal "volume", precision: 20, scale: 2
    t.index ["asset_id", "interval", "candle_time"], name: "index_candles_on_asset_id_and_interval_and_candle_time", unique: true
    t.index ["asset_id", "interval"], name: "index_candles_on_asset_id_and_interval"
    t.index ["candle_time"], name: "index_candles_on_candle_time"
  end

  create_table "daily_reports", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.string "generated_by", default: "ai"
    t.integer "generation_time_ms"
    t.string "model_version"
    t.boolean "published", default: false
    t.date "report_date", null: false
    t.string "report_type", null: false
    t.jsonb "statistics", default: {}
    t.text "summary"
    t.datetime "updated_at", null: false
    t.index ["published"], name: "index_daily_reports_on_published"
    t.index ["report_date"], name: "index_daily_reports_on_report_date"
    t.index ["report_type", "report_date"], name: "index_daily_reports_on_report_type_and_report_date", unique: true
    t.index ["report_type"], name: "index_daily_reports_on_report_type"
  end

  create_table "factor_definitions", force: :cascade do |t|
    t.boolean "active", default: true
    t.string "calculation_method", null: false
    t.string "category", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.text "formula"
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

  create_table "job_executions", force: :cascade do |t|
    t.text "arguments"
    t.datetime "created_at", null: false
    t.integer "duration_ms"
    t.text "error_message"
    t.datetime "finished_at"
    t.string "job_id", null: false
    t.string "job_name", null: false
    t.string "queue_name"
    t.datetime "started_at", null: false
    t.string "status", default: "running", null: false
    t.datetime "updated_at", null: false
    t.index ["job_id"], name: "index_job_executions_on_job_id", unique: true
    t.index ["job_name"], name: "index_job_executions_on_job_name"
    t.index ["started_at"], name: "index_job_executions_on_started_at"
    t.index ["status"], name: "index_job_executions_on_status"
  end

  create_table "portfolio_snapshots", force: :cascade do |t|
    t.bigint "allocation_task_id"
    t.datetime "captured_at", null: false
    t.decimal "cash_value", precision: 15, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.decimal "invested_value", precision: 15, scale: 2, default: "0.0", null: false
    t.jsonb "metadata", default: {}, null: false
    t.decimal "portfolio_value", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "profit_loss", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "profit_loss_percent", precision: 8, scale: 2, default: "0.0", null: false
    t.date "snapshot_date", null: false
    t.string "source", default: "execution", null: false
    t.bigint "trader_id", null: false
    t.datetime "updated_at", null: false
    t.index ["allocation_task_id"], name: "index_portfolio_snapshots_on_allocation_task_id"
    t.index ["source"], name: "index_portfolio_snapshots_on_source"
    t.index ["trader_id", "captured_at"], name: "index_portfolio_snapshots_on_trader_id_and_captured_at"
    t.index ["trader_id", "snapshot_date"], name: "index_portfolio_snapshots_on_trader_id_and_snapshot_date"
    t.index ["trader_id"], name: "index_portfolio_snapshots_on_trader_id"
  end

  create_table "trader_positions", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "asset_id", null: false
    t.decimal "average_cost", precision: 15, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.decimal "current_price", precision: 15, scale: 2, default: "0.0", null: false
    t.datetime "last_rebalanced_at"
    t.decimal "market_value", precision: 15, scale: 2, default: "0.0", null: false
    t.datetime "opened_at"
    t.decimal "quantity", precision: 20, scale: 8, default: "0.0", null: false
    t.bigint "trader_id", null: false
    t.decimal "unrealized_pnl", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "unrealized_pnl_percent", precision: 8, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_id"], name: "index_trader_positions_on_asset_id"
    t.index ["trader_id", "active"], name: "index_trader_positions_on_trader_id_and_active"
    t.index ["trader_id", "asset_id"], name: "index_trader_positions_on_trader_id_and_asset_id", unique: true
    t.index ["trader_id"], name: "index_trader_positions_on_trader_id"
  end

  create_table "trader_trades", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "allocation_decision_id", null: false
    t.bigint "allocation_task_id", null: false
    t.decimal "amount", precision: 15, scale: 2, null: false
    t.bigint "asset_id", null: false
    t.datetime "created_at", null: false
    t.datetime "executed_at", null: false
    t.decimal "price", precision: 15, scale: 2, null: false
    t.decimal "quantity", precision: 20, scale: 8, null: false
    t.text "reason"
    t.bigint "trader_id", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_trader_trades_on_action"
    t.index ["allocation_decision_id"], name: "index_trader_trades_on_allocation_decision_id"
    t.index ["allocation_task_id", "asset_id"], name: "index_trader_trades_on_allocation_task_id_and_asset_id"
    t.index ["allocation_task_id"], name: "index_trader_trades_on_allocation_task_id"
    t.index ["asset_id"], name: "index_trader_trades_on_asset_id"
    t.index ["trader_id", "executed_at"], name: "index_trader_trades_on_trader_id_and_executed_at"
    t.index ["trader_id"], name: "index_trader_trades_on_trader_id"
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
    t.integer "user_id", null: false
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
    t.integer "trader_id", null: false
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

  add_foreign_key "allocation_decisions", "traders"
  add_foreign_key "allocation_decisions", "trading_strategies"
  add_foreign_key "allocation_tasks", "allocation_decisions"
  add_foreign_key "allocation_tasks", "traders"
  add_foreign_key "asset_snapshots", "assets"
  add_foreign_key "candles", "assets"
  add_foreign_key "factor_values", "assets"
  add_foreign_key "factor_values", "factor_definitions"
  add_foreign_key "portfolio_snapshots", "allocation_tasks"
  add_foreign_key "portfolio_snapshots", "traders"
  add_foreign_key "trader_positions", "assets"
  add_foreign_key "trader_positions", "traders"
  add_foreign_key "trader_trades", "allocation_decisions"
  add_foreign_key "trader_trades", "allocation_tasks"
  add_foreign_key "trader_trades", "assets"
  add_foreign_key "trader_trades", "traders"
  add_foreign_key "trading_signals", "assets"
end
