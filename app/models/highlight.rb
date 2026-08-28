class Highlight < ApplicationRecord
  belongs_to :match
  belongs_to :match_player, optional: true
  belongs_to :injured_match_player, class_name: "MatchPlayer", optional: true

  validates :event, presence: true

  scope :touchdowns, -> { where(event: "touch_down") }
  scope :injuries, -> { where(event: "injury_caused") }
  scope :by_event, ->(event) { where(event: event) }

  # Name of the non-actor player involved in the highlight. The injury_caused
  # events carry the victim via injured_match_player; kick and loss_of_ball
  # events carry the receiver/recoverer only in the raw data blob.
  def target_player_name
    return injured_match_player&.name if injured_match_player

    data&.dig("received_by", "player_name") || data&.dig("recovered_by", "player_name")
  end
end
