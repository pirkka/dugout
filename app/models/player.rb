class Player < ApplicationRecord
  ACTIVE = "active"
  MNG = "mng"
  FIRED = "fired"
  DEAD = "dead"

  belongs_to :team
  has_many :match_players, dependent: :destroy

  validates :team_id, uniqueness: { scope: :number }, if: -> { number.present? }
  validates :name, presence: true
  validates :status, inclusion: { in: [ACTIVE, MNG, FIRED, DEAD] }

  # Resolve a player's identity for a team. Player numbers renumber when the
  # roster changes, and names can be changed in BB3, so we match by name first
  # (renumber-safe) and fall back to the number slot (rename-safe).
  #
  # Trade-off: if a player is sold and replaced by a different player, the
  # system is unable to distinguish this from player development. The next
  # version can at least start checking if the player's class changes, stats
  # go downwards between games, or other evidence that the player has changed.
  #
  # One case is treated as hard data: a dead player never plays again, so a
  # new name taking over their number is a new player, not a rename.
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
      if by_number.dead?
        by_number.update!(number: nil)
        return create!(team: team, number: number, name: name)
      end
      by_number.update!(name: name) unless by_number.name == name
      return by_number
    end

    create!(team: team, number: number, name: name)
  end

  def dead?
    match_players.exists?(status: DEAD) || match_players.exists?(injury_type: DEAD)
  end

  def self.free_number(team, number, excluding:)
    occupant = find_by(team_id: team.id, number: number)
    occupant.update!(number: nil) if occupant && occupant != excluding
  end

  # Lifecycle status is derived from hard data:
  # - dead: the player died (version status or injury event), terminal
  # - mng: the player suffered a "Miss next game" injury in the team's most
  #   recent match, so they are unavailable for the next one. Once the team
  #   plays another match the mng is consumed and the player recovers.
  # - fired: the player's number was taken over (Player.resolve frees it when
  #   the roster changes) or they have missed 2+ consecutive matches.
  # - active: everything else.
  def compute_status
    return DEAD if match_players.any? { |v| v.status == DEAD || v.injury_type == DEAD }

    latest = match_players.joins(:match)
      .order(Arel.sql("COALESCE(matches.started, matches.finished) DESC"))
      .first
    if latest&.injury_type == MNG && latest.match == team_latest_played_match
      return MNG
    end

    match_ids = team.matches.joins(:match_players).distinct
      .order(Arel.sql("COALESCE(matches.started, matches.finished)"))
      .pluck(:id)
    played_ids = match_players.pluck(:match_id)
    first_index = match_ids.index { |id| played_ids.include?(id) }
    return ACTIVE unless first_index

    consecutive_misses = 0
    match_ids[first_index..].reverse_each do |id|
      played_ids.include?(id) ? break : consecutive_misses += 1
    end

    return FIRED if number.nil? || consecutive_misses >= 2

    ACTIVE
  end

  def refresh_status!
    computed = compute_status
    update!(status: computed) unless status == computed
    computed
  end

  private

  def team_latest_played_match
    team.matches
      .where("started IS NOT NULL OR finished IS NOT NULL")
      .order(Arel.sql("COALESCE(matches.started, matches.finished) DESC"))
      .first
  end
end
