class RenameGoalsToTouchdowns < ActiveRecord::Migration[8.1]
  def change
    rename_column :competition_teams, :goals_made, :touchdowns_made
    rename_column :competition_teams, :goals_sustained, :touchdowns_sustained
    rename_column :series_teams, :goals_made, :touchdowns_made
    rename_column :series_teams, :goals_sustained, :touchdowns_sustained
  end
end
