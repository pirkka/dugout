class AddPointsAndPositionToCompetitionTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :competition_teams, :points, :integer
    add_column :competition_teams, :position, :integer
  end
end
