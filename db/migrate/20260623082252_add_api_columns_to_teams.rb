class AddApiColumnsToTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :teams, :api_id, :string
    add_column :teams, :api_data, :json
    add_index :teams, :api_id
    remove_column :teams, :inception, :string
  end
end
