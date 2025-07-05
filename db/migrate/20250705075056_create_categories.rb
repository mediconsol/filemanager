class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.string :label, null: false
      t.text :description
      t.boolean :is_active, default: true
      t.integer :sort_order, default: 0

      t.timestamps
    end

    add_index :categories, :name, unique: true
    add_index :categories, :is_active
    add_index :categories, :sort_order
  end
end
