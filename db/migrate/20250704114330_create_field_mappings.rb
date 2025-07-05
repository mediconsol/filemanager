class CreateFieldMappings < ActiveRecord::Migration[8.0]
  def change
    create_table :field_mappings do |t|
      t.references :hospital, null: false, foreign_key: true
      t.references :data_upload, null: true, foreign_key: true
      t.string :source_field, null: false
      t.string :target_field, null: false
      t.string :mapping_type, default: 'direct' # direct, calculated, lookup, conditional
      t.string :data_type # string, integer, decimal, date, boolean
      t.text :transformation_rules # JSON 형태의 변환 규칙
      t.text :validation_rules # JSON 형태의 검증 규칙
      t.boolean :is_required, default: false
      t.boolean :is_active, default: true
      t.string :description
      t.integer :order_index

      t.timestamps
    end


    add_index :field_mappings, [:source_field, :target_field]
    add_index :field_mappings, :mapping_type
    add_index :field_mappings, :is_active
  end
end
