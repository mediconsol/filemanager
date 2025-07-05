class CreateHospitals < ActiveRecord::Migration[8.0]
  def change
    create_table :hospitals do |t|
      t.string :name, null: false
      t.string :plan, default: 'basic' # basic, pro, enterprise
      t.string :domain
      t.text :settings # JSON 설정 저장
      t.string :address
      t.string :phone
      t.string :email
      t.string :license_number
      t.boolean :is_active, default: true

      t.timestamps
    end

    add_index :hospitals, :domain, unique: true
    add_index :hospitals, :name
    add_index :hospitals, :is_active
  end
end
