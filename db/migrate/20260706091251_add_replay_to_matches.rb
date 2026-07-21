class AddReplayToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :replay_data, :binary
    add_column :matches, :replay_file_name, :string
  end
end
