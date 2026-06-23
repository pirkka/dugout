class AddApiColumnsToCompetitions < ActiveRecord::Migration[8.1]
  def change
    add_column :competitions, :api_id, :string
    add_column :competitions, :api_data, :json
    add_index :competitions, :api_id
  end
end
