class PlayerVersion < ApplicationRecord
  belongs_to :player
  belongs_to :match

  validates :player_id, uniqueness: { scope: :match_id }
end
