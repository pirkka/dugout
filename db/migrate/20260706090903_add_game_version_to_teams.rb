class AddGameVersionToTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :teams, :game_version, :integer, null: false, default: 2
  end
end
