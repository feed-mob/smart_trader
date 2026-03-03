class CreateFactorValues < ActiveRecord::Migration[8.1]
  def change
    create_table :factor_values do |t|
      t.references :asset, null: false, foreign_key: true
      t.references :factor_definition, null: false, foreign_key: true
      t.decimal :raw_value, precision: 15, scale: 6
      t.decimal :normalized_value, precision: 10, scale: 6
      t.decimal :percentile, precision: 5, scale: 2
      t.datetime :calculated_at, null: false

      t.timestamps
    end

    add_index :factor_values, [:asset_id, :factor_definition_id, :calculated_at],
              unique: true, name: 'idx_factor_values_unique'
    add_index :factor_values, :calculated_at
  end
end
