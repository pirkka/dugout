class AddScoreToCompetitionTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :competition_teams, :score, :integer
  end
end
