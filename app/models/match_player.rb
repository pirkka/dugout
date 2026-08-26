class MatchPlayer < ApplicationRecord
  belongs_to :player
  belongs_to :match

  validates :player_id, uniqueness: { scope: :match_id }

  scope :newest_first, -> { joins(:match).order(Arel.sql("COALESCE(matches.started, matches.finished) DESC")) }
end
