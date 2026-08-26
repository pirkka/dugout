class RenamePlayerVersionsToMatchPlayers < ActiveRecord::Migration[8.1]
  def change
    rename_table :player_versions, :match_players
  end
end
