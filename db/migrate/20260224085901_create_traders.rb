class CreateTraders < ActiveRecord::Migration[8.1]
  def change
    create_table :traders do |t|
      t.string :name, null: false
      t.integer :risk_level, default: 0  # 0: conservative, 1: balanced, 2: aggressive
      t.decimal :initial_capital, precision: 15, scale: 2, default: 100000.0
      t.decimal :current_capital, precision: 15, scale: 2
      t.integer :status, default: 0  # 0: active, 1: inactive
      t.text :description  # 投资风格描述，用于 LLM 分析

      t.timestamps
    end

    add_index :traders, :status
  end
end
