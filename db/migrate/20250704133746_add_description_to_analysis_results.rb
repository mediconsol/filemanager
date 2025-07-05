class AddDescriptionToAnalysisResults < ActiveRecord::Migration[8.0]
  def change
    add_column :analysis_results, :description, :text
  end
end
