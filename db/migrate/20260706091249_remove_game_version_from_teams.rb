class RemoveGameVersionFromTeams < ActiveRecord::Migration[8.1]
  def change
    remove_column :teams, :game_version, :integer
  end
end
