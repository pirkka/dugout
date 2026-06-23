class AddApiColumnsToLeagues < ActiveRecord::Migration[8.1]
  def change
    add_column :leagues, :api_id, :string
    add_column :leagues, :api_data, :json
    add_index :leagues, :api_id
  end
end
