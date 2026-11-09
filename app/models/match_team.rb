class MatchTeam < ApplicationRecord
  belongs_to :match
  belongs_to :team

  enum :result, { win: 0, loss: 1, draw: 2 }

  # The Cyanide API occasionally returns casualty counts as strings, so
  # coerce them before they are summed with integer totals.
  def inflicted_casualties
    api_data&.dig("inflictedcasualties").to_i
  end

  def sustained_casualties
    api_data&.dig("sustainedcasualties").to_i
  end
end
