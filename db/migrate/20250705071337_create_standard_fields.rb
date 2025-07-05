class CreateStandardFields < ActiveRecord::Migration[8.0]
  def change
    create_table :standard_fields do |t|
      t.string :name, null: false
      t.string :label, null: false
      t.text :description
      t.string :data_type, null: false, default: 'string'
      t.string :category, null: false
      t.boolean :is_required, default: false
      t.boolean :is_active, default: true
      t.integer :sort_order, default: 0
      t.json :validation_rules
      t.string :default_value

      t.timestamps
    end

    add_index :standard_fields, [:category, :sort_order]
    add_index :standard_fields, :name, unique: true
    add_index :standard_fields, :is_active
  end
end
