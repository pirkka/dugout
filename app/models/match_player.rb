class MatchPlayer < ApplicationRecord
  belongs_to :player
  belongs_to :match
  has_many :highlights, dependent: :nullify
  has_many :injury_highlights, class_name: "Highlight", foreign_key: :injured_match_player_id, dependent: :nullify

  validates :player_id, uniqueness: { scope: :match_id }

  scope :newest_first, -> { joins(:match).order(Arel.sql("COALESCE(matches.started, matches.finished) DESC")) }
end
