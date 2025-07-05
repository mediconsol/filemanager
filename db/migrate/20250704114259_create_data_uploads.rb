class CreateDataUploads < ActiveRecord::Migration[8.0]
  def change
    create_table :data_uploads do |t|
      t.references :hospital, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :file_name, null: false
      t.integer :file_size
      t.string :file_type
      t.string :status, default: 'pending' # pending, processing, completed, failed
      t.string :data_category # financial, operational, quality, patient
      t.text :file_path # 실제 파일 저장 경로
      t.text :original_data # JSON 형태의 원본 데이터
      t.text :processed_data # JSON 형태의 처리된 데이터
      t.text :validation_errors # JSON 형태의 검증 오류
      t.text :error_message
      t.integer :total_rows
      t.integer :processed_rows
      t.integer :error_rows
      t.datetime :processing_started_at
      t.datetime :processing_completed_at

      t.timestamps
    end


    add_index :data_uploads, :status
    add_index :data_uploads, :data_category
    add_index :data_uploads, :created_at
  end
end
