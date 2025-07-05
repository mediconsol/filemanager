class CreateAnalysisResults < ActiveRecord::Migration[8.0]
  def change
    create_table :analysis_results do |t|
      t.references :hospital, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :analysis_type
      t.text :parameters
      t.text :result_data
      t.text :chart_config
      t.timestamps
    end
  end
end
