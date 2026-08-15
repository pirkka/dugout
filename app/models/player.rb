class Player < ApplicationRecord
  belongs_to :team
  has_many :player_versions, dependent: :destroy

  validates :team_id, uniqueness: { scope: :number }, if: -> { number.present? }
  validates :name, presence: true

  # Resolve a player's identity for a team. Player numbers renumber when the
  # roster changes, and names can be changed in BB3, so we match by name first
  # (renumber-safe) and fall back to the number slot (rename-safe).
  #
  # Trade-off: if a player is sold and replaced by a different player, the
  # system is unable to distinguish this from player development. In the next
  # version, we can at least start checking if the player's class changes,
  # stats go downwards between games, or other evidence that the player has
  # changed to a new player.
  def self.resolve(team, number:, name:)
    return nil unless team && number

    by_name = find_by(team_id: team.id, name: name)
    if by_name
      free_number(team, number, excluding: by_name)
      by_name.update!(number: number) unless by_name.number == number
      return by_name
    end

    by_number = find_by(team_id: team.id, number: number)
    if by_number
      by_number.update!(name: name) unless by_number.name == name
      return by_number
    end

    create!(team: team, number: number, name: name)
  end

  def self.free_number(team, number, excluding:)
    occupant = find_by(team_id: team.id, number: number)
    occupant.update!(number: nil) if occupant && occupant != excluding
  end
end
