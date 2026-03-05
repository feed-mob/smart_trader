class AddFormulaToFactorDefinitions < ActiveRecord::Migration[8.1]
  def change
    add_column :factor_definitions, :formula, :text
  end
end
