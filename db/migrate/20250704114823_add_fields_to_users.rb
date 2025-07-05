class AddFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_reference :users, :hospital, null: false, foreign_key: true
    add_column :users, :name, :string, null: false
    add_column :users, :role, :string, default: 'viewer' # admin, analyst, viewer
    add_column :users, :department, :string
    add_column :users, :position, :string
    add_column :users, :phone, :string
    add_column :users, :is_active, :boolean, default: true
    add_column :users, :last_login_at, :datetime
    add_column :users, :avatar_url, :string

    add_index :users, [:hospital_id, :email], unique: true
    add_index :users, :role
    add_index :users, :is_active
    add_index :users, :department
  end
end
