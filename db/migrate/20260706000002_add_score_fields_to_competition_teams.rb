class AddScoreFieldsToCompetitionTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :competition_teams, :goals_made, :integer
    add_column :competition_teams, :goals_sustained, :integer
    add_column :competition_teams, :casualties_made, :integer
    add_column :competition_teams, :casualties_sustained, :integer
  end
end
