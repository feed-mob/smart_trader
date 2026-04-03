# frozen_string_literal: true

namespace :traders do
  desc "List all traders with their IDs and current information"
  task list: :environment do
    puts "=" * 100
    puts "All Traders in Database"
    puts "=" * 100
    puts format("%-6s | %-30s | %-15s | %-15s | %-10s | %-10s",
              "ID", "Name", "Risk Level", "Status", "Initial Cap", "Current Cap")
    puts "-" * 100

    Trader.all.each do |trader|
      puts format("%-6s | %-30s | %-15s | %-15s | $%-9s | $%-9s",
                trader.id,
                trader.name[0..29],
                trader.risk_level,
                trader.status,
                number_with_delimiter(trader.initial_capital),
                number_with_delimiter(trader.current_capital_value))
    end

    puts "=" * 100
    puts "Total: #{Trader.count} traders"
    puts "=" * 100
  end

  desc "Update trader by ID (usage: rails traders:update[id]='New Name')"
  task :update, [:id] => :environment do |_t, args|
    id = args[:id]
    new_name = ENV['NAME']
    new_description = ENV['DESCRIPTION']
    new_risk_level = ENV['RISK_LEVEL']
    new_status = ENV['STATUS']
    new_initial_capital = ENV['INITIAL_CAPITAL']

    unless id
      puts "Error: Please provide trader ID"
      puts "Usage: rails 'traders:update[1]' NAME='New Name' DESCRIPTION='New description'"
      exit 1
    end

    trader = Trader.find_by(id: id)
    unless trader
      puts "Error: Trader with ID #{id} not found"
      exit 1
    end

    puts "Current Trader Information:"
    puts "  ID: #{trader.id}"
    puts "  Name: #{trader.name}"
    puts "  Description: #{trader.description}"
    puts "  Risk Level: #{trader.risk_level}"
    puts "  Status: #{trader.status}"
    puts "  Initial Capital: $#{number_with_delimiter(trader.initial_capital)}"

    updates = {}
    updates[:name] = new_name if new_name.present?
    updates[:description] = new_description if new_description.present?
    updates[:risk_level] = new_risk_level if new_risk_level.present?
    updates[:status] = new_status if new_status.present?
    updates[:initial_capital] = new_initial_capital.to_f if new_initial_capital.present?

    if updates.empty?
      puts "\nNo updates provided. Use environment variables:"
      puts "  NAME='New Name'"
      puts "  DESCRIPTION='New description'"
      puts "  RISK_LEVEL='conservative|balanced|aggressive'"
      puts "  STATUS='active|inactive'"
      puts "  INITIAL_CAPITAL='100000'"
      exit 0
    end

    if trader.update(updates)
      puts "\n✓ Trader updated successfully!"
      puts "  Updated fields: #{updates.keys.join(', ')}"
    else
      puts "\n✗ Update failed:"
      trader.errors.full_messages.each do |error|
        puts "  - #{error}"
      end
      exit 1
    end
  end

  desc "Batch rename traders from a mapping (usage: rails traders:batch_rename FILE=path/to/mapping.json)"
  task batch_rename: :environment do
    file_path = ENV['FILE'] || 'lib/tasks/trader_name_mapping.json'

    unless File.exist?(file_path)
      puts "Error: Mapping file not found at #{file_path}"
      puts "Please create a JSON file with the following format:"
      puts json_example
      exit 1
    end

    begin
      mapping = JSON.parse(File.read(file_path))
    rescue JSON::ParserError => e
      puts "Error: Invalid JSON file - #{e.message}"
      exit 1
    end

    puts "=" * 100
    puts "Batch Renaming Traders"
    puts "=" * 100
    puts "Mapping file: #{file_path}"
    puts "=" * 100

    success_count = 0
    failed_count = 0

    mapping.each do |entry|
      old_name = entry['old_name']
      new_name = entry['new_name']
      new_description = entry['description']
      new_risk_level = entry['risk_level']

      trader = Trader.find_by(name: old_name)

      if trader
        updates = {}
        updates[:name] = new_name if new_name.present?
        updates[:description] = new_description if new_description.present?
        updates[:risk_level] = new_risk_level if new_risk_level.present?

        if trader.update(updates)
          # Regenerate strategies with new English LLM prompts
          trader.trading_strategies.destroy_all
          service = StrategyGeneratorService.new(trader.description, risk_level: trader.risk_level)
          strategies = service.generate_strategies
          strategies.each { |params| trader.trading_strategies.create(params) }

          success_count += 1
          puts "✓ Updated: '#{old_name}' -> '#{new_name}' (strategies regenerated)"
        else
          failed_count += 1
          puts "✗ Failed: '#{old_name}' - #{trader.errors.full_messages.join(', ')}"
        end
      else
        failed_count += 1
        puts "✗ Not found: '#{old_name}'"
      end
    end

    puts "=" * 100
    puts "Batch rename completed!"
    puts "  Success: #{success_count}"
    puts "  Failed: #{failed_count}"
    puts "=" * 100
  end

  desc "Generate sample trader name mapping JSON file"
  task generate_mapping: :environment do
    mapping_file = 'lib/tasks/trader_name_mapping.json'

    mapping = Trader.all.map do |trader|
      {
        'old_name' => trader.name,
        'new_name' => '',
        'description' => trader.description || '',
        'risk_level' => trader.risk_level
      }
    end

    File.write(mapping_file, JSON.pretty_generate(mapping))

    puts "=" * 100
    puts "Generated mapping file: #{mapping_file}"
    puts "=" * 100
    puts "Edit this file with the new names, then run:"
    puts "  rails traders:batch_rename FILE=#{mapping_file}"
    puts "=" * 100
  end

  desc "Regenerate English strategies for all traders (using matrix strategies, already in English)"
  task regenerate_strategies: :environment do
    puts "=" * 100
    puts "Regenerating English Strategies for All Traders"
    puts "=" * 100

    success_count = 0
    failed_count = 0

    Trader.all.each do |trader|
      # Delete related records first to avoid foreign key issues
      reflection_ids = trader.trader_reflections.pluck(:id)
      StrategyAdjustmentLog.where(trader_reflection_id: reflection_ids).delete_all
      trader.trading_strategies.destroy_all

      # Use matrix strategies directly (already in English)
      TradingStrategy.market_conditions.keys.each do |market_condition|
        matrix_params = TradingStrategy.strategy_for(trader.risk_level, market_condition)
        trader.trading_strategies.create(
          name: matrix_params[:name],
          risk_level: trader.risk_level,
          max_positions: matrix_params[:max_positions],
          buy_signal_threshold: matrix_params[:buy_signal_threshold],
          max_position_size: matrix_params[:max_position_size],
          min_cash_reserve: matrix_params[:min_cash_reserve],
          description: matrix_params[:description],
          market_condition: market_condition,
          generated_by: :matrix
        )
      end

      success_count += 1
      puts "✓ Regenerated strategies for: '#{trader.name}' (ID: #{trader.id})"
    rescue => e
      failed_count += 1
      puts "✗ Failed: '#{trader.name}' (ID: #{trader.id}) - #{e.message}"
    end

    puts "=" * 100
    puts "Completed! Regenerated strategies for #{success_count} traders"
    puts "Failed: #{failed_count}"
    puts "=" * 100
  end

  desc "Rebuild allocation task summaries in English from existing data"
  task rebuild_task_summaries: :environment do
    puts "=" * 100
    puts "Rebuilding Allocation Task Summaries in English"
    puts "=" * 100

    updated_count = 0

    AllocationTask.find_each do |task|
      # Rebuild summary based on task status and data
      if task.status == "completed"
        trade_count = task.trader_trades.count
        portfolio_value = task.portfolio_value
        new_summary = "Executed #{trade_count} position updates, latest portfolio value #{portfolio_value.to_f.round(2)}."
      elsif task.status == "failed"
        new_summary = "Execution failed: #{task.error_message || 'Unknown error'}"
      elsif task.status == "running"
        new_summary = "Starting execution of allocation decision ##{task.allocation_decision_id}"
      else
        new_summary = "Task status: #{task.status}"
      end

      if task.summary != new_summary
        task.update(summary: new_summary)
        updated_count += 1
        puts "✓ Updated task #{task.id}: #{new_summary[0..60]}..."
      end
    end

    puts "=" * 100
    puts "Rebuilt #{updated_count} task summary(s)"
    puts "=" * 100
  end

  desc "Translate allocation task summaries from Chinese to English"
  task translate_task_summaries: :environment do
    puts "=" * 100
    puts "Translating Allocation Task Summaries"
    puts "=" * 100

    # Common translations
    translations = {
      "执行" => "Executed",
      "个目标仓位更新" => "target position updates",
      "最新组合净值" => "latest portfolio value",
      "开始执行" => "Starting execution of",
      "执行失败" => "Execution failed",
      "资产不在最新 recommendation 目标组合中" => "Asset not in latest recommendation target portfolio"
    }

    updated_count = 0

    AllocationTask.where.not(summary: [nil, ""]).find_each do |task|
      original_summary = task.summary
      translated = original_summary.dup

      # Apply translations
      translations.each do |chinese, english|
        translated.gsub!(chinese, english)
      end

      # Only update if translation actually changed something
      if translated != original_summary
        task.update(summary: translated)
        updated_count += 1
        puts "✓ Updated: #{original_summary[0..50]}... -> #{translated[0..50]}..."
      end
    end

    puts "=" * 100
    puts "Translated #{updated_count} task summary(s)"
    puts "=" * 100
  end

  desc "Clear old allocation task summaries (optional: these are historical records)"
  task clear_task_summaries: :environment do
    puts "=" * 100
    puts "Clearing Old Allocation Task Summaries"
    puts "=" * 100

    updated_count = AllocationTask.where.not(summary: [nil, ""]).update_all(summary: nil)

    puts "Cleared #{updated_count} task summary(s)"
    puts "=" * 100
    puts "Cleared! New tasks will have English summaries"
    puts "=" * 100
  end

  desc "Clear all trader reflections (will be regenerated with English prompts)"
  task clear_reflections: :environment do
    puts "=" * 100
    puts "Clearing All Trader Reflections"
    puts "=" * 100

    # Delete strategy adjustment logs first
    reflection_ids = TraderReflection.pluck(:id)
    deleted_logs = StrategyAdjustmentLog.where(trader_reflection_id: reflection_ids).delete_all

    # Delete reflections
    deleted_count = TraderReflection.delete_all

    puts "Deleted #{deleted_count} reflection(s)"
    puts "Deleted #{deleted_logs} strategy adjustment log(s)"
    puts "=" * 100
    puts "Cleared! Use 'traders:regenerate_reflections' to regenerate in English"
    puts "=" * 100
  end

  desc "Regenerate all trader reflections with English prompts"
  task regenerate_reflections: :environment do
    puts "=" * 100
    puts "Regenerating Trader Reflections with English Prompts"
    puts "=" * 100

    success_count = 0
    failed_count = 0

    Trader.all.each do |trader|
      period_end = Date.current
      period_start = 30.days.ago.to_date

      begin
        # Check if reflection already exists
        existing = trader.trader_reflections.find_by(
          reflection_period_start: period_start,
          reflection_period_end: period_end
        )

        if existing
          puts "⊘ Skipping: '#{trader.name}' (ID: #{trader.id}) - already exists"
          next
        end

        service = TraderReflectionService.new(trader,
          period_start: period_start,
          period_end: period_end
        )
        service.call
        success_count += 1
        puts "✓ Generated: '#{trader.name}' (ID: #{trader.id})"
      rescue => e
        failed_count += 1
        puts "✗ Failed: '#{trader.name}' (ID: #{trader.id}) - #{e.message}"
      end
    end

    puts "=" * 100
    puts "Completed! Generated #{success_count} reflections"
    puts "Failed: #{failed_count}"
    puts "=" * 100
  end

  desc "Reset all trader names to English based on risk level"
  task reset_names: :environment do
    name_templates = {
      'conservative' => [
        'Conservative Growth Fund',
        'Steady Income Portfolio',
        'Capital Preservation Fund',
        'Low Risk Strategy',
        'Defensive Investor'
      ],
      'balanced' => [
        'Balanced Growth Fund',
        'Core Satellite Portfolio',
        'Moderate Strategy',
        'Diversified Income Fund',
        'Dynamic Asset Allocator'
      ],
      'aggressive' => [
        'Aggressive Growth Fund',
        'High Momentum Strategy',
        'Opportunistic Portfolio',
        'Growth at Reasonable Price',
        'Tactical Trader Fund'
      ]
    }

    puts "=" * 100
    puts "Resetting Trader Names to English"
    puts "=" * 100

    success_count = 0
    Trader.all.each do |trader|
      names = name_templates[trader.risk_level] || name_templates['balanced']
      new_name = names[trader.id % names.length]

      if trader.update(name: "#{new_name} ##{trader.id}")
        success_count += 1
        puts "✓ Updated: #{trader.id} -> '#{trader.name}'"
      else
        puts "✗ Failed: #{trader.id} - #{trader.errors.full_messages.join(', ')}"
      end
    end

    puts "=" * 100
    puts "Completed! Updated #{success_count} traders"
    puts "=" * 100
  end

  private

  def number_with_delimiter(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end

  def json_example
    <<~JSON
      [
        {
          "old_name": "当前名称1",
          "new_name": "New Name 1",
          "description": "New description for this trader",
          "risk_level": "conservative"
        },
        {
          "old_name": "当前名称2",
          "new_name": "New Name 2",
          "description": "New description for this trader",
          "risk_level": "balanced"
        }
      ]
    JSON
  end
end
