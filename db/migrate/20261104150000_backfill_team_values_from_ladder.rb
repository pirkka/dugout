class BackfillTeamValuesFromLadder < ActiveRecord::Migration[8.1]
  def up
    Team.reset_column_information
    CompetitionTeam.reset_column_information

    CompetitionTeam.where.not(api_data: nil).order(:updated_at).find_each do |competition_team|
      tv = competition_team.api_data.dig("team", "tv")
      next if tv.nil?

      competition_team.team.update_column(:value, tv)
    end
  end

  def down
  end
end
