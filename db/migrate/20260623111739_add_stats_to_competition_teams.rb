class AddStatsToCompetitionTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :competition_teams, :matches, :integer
    add_column :competition_teams, :wins, :integer
    add_column :competition_teams, :losses, :integer
    add_column :competition_teams, :draws, :integer
  end
end
