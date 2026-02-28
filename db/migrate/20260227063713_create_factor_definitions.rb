class CreateFactorDefinitions < ActiveRecord::Migration[8.1]
  def change
    create_table :factor_definitions do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.text :description
      t.string :category, null: false
      t.string :calculation_method, null: false
      t.jsonb :parameters, default: {}
      t.decimal :weight, precision: 5, scale: 4, default: 0.1
      t.integer :update_frequency, default: 60
      t.boolean :active, default: true
      t.integer :sort_order, default: 0

      t.timestamps
    end

    add_index :factor_definitions, :code, unique: true
    add_index :factor_definitions, :category
    add_index :factor_definitions, :active
  end
end
