class Contest < ApplicationRecord
  belongs_to :competition
  belongs_to :home_team, class_name: "Team", optional: true
  belongs_to :away_team, class_name: "Team", optional: true

  # In-progress score from the stored API payload (present on live games).
  def home_score
    api_score_for(home_team)
  end

  def away_score
    api_score_for(away_team)
  end

  private

  def api_score_for(team)
    return nil if team.nil?
    Array(api_data&.dig("opponents")).each do |opponent|
      return opponent.dig("team", "score") if opponent.dig("team", "id").to_s == team.api_id.to_s
    end
    nil
  end
end
