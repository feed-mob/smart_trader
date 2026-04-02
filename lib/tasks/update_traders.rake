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
          success_count += 1
          puts "✓ Updated: '#{old_name}' -> '#{new_name}'"
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
