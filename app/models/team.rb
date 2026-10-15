class Team < ApplicationRecord
  belongs_to :coach, optional: true
  has_many :competition_teams, dependent: :destroy
  has_many :competitions, through: :competition_teams
  has_many :series_teams, dependent: :destroy
  has_many :series, through: :series_teams
  has_many :match_teams, dependent: :destroy
  has_many :matches, through: :match_teams
  has_many :players, dependent: :destroy
  has_one :lifetime_stat, class_name: "TeamLifetimeStat", dependent: :destroy

  def upcoming_contests
    Contest.where(competition_id: competitions.select(:id))
      .where("home_team_id = :team_id OR away_team_id = :team_id", team_id: id)
      .order(Arel.sql("CASE WHEN round IS NULL THEN 1 ELSE 0 END, round, match_date"))
  end

  def current_roster
    roster_match_players([Player::ACTIVE, Player::MNG])
  end

  def departed_roster
    roster_match_players([Player::FIRED, Player::DEAD])
  end

  def to_param
    slug
  end

  def logo_url
    filename_prefix = game_version.to_sym == :bb3 ? "" : "Logo_"
    "https://images.cyanide-studio.com/#{game_version}/logos/#{filename_prefix}#{logo}.png"
  end

  def game_version
    competitions.first.game_version
  end

  def platform
    competitions.first.platform
  end

  def refresh
    client = CyanideApi::Client.new
    data = client.team(team_id: api_id, game_version: competitions.first.league.game_version)
    update!(api_data: data)
    parse_api_data(data)
    true
  rescue CyanideApi::NotFoundError
    errors.add(:base, "Team not found on API")
    false
  rescue CyanideApi::Error => e
    errors.add(:base, e.message)
    false
  end

  def parse_api_data(data)
    self.name = data["team"]["name"]
    self.slug = self.name.parameterize
    self.value = data["team"]["value"]
    self.cash = data["team"]["cash"]
    self.rerolls = data["team"]["rerolls"]
    self.apothecary = data["team"]["apothecary"]
    self.assistant_coaches = data["team"]["assistant_coaches"]
    self.cheerleaders = data["team"]["cheerleaders"]
    self.popularity = data["team"]["popularity"]
    self.logo = data["team"]["logo"]
    self.established = data["team"]["created"]
    self.slogan = data.dig("team", "leitmotiv") if game_version == :bb2
    # find or create coach
    coach = Coach.find_or_create_by!(api_id: data["coach"]["id"].to_s) do |new_coach|
      new_coach.name = data["coach"]["name"]
      new_coach.slug = data["coach"]["name"].parameterize
    end
    coach.update!(
      name: data["coach"]["name"],
      slug: data["coach"]["name"].parameterize
    )
    self.coach = coach
    save!
  end

  def cyanide_uri
    api_key = Rails.application.credentials.cyanide_api_key
    game_version = self.competitions.first.league.game_version
    "https://web.cyanide-studio.com/ws/#{game_version}/team/?key=#{api_key}&id=#{api_id}&stats=1"
  end

  # Rebuilds the cached lifetime tally from all MatchTeam rows. Uses the
  # same W/D/L + points (3/1/0) convention as Competition#calculate_standings
  # and the same TD/CAS sums as Competition#calculate_team_stats, across
  # all competitions. Only surviving MatchTeam rows count (duplicates
  # destroyed by Competition#remove_duplicate_matches are excluded).
  def recalculate_lifetime_stats!
    mts = MatchTeam.where(team_id: id)
    wins = mts.win.count
    draws = mts.draw.count
    losses = mts.loss.count
    stat = lifetime_stat || build_lifetime_stat
    stat.update!(
      matches: wins + draws + losses,
      wins: wins,
      draws: draws,
      losses: losses,
      points: wins * 3 + draws,
      touchdowns_made: mts.sum(:score),
      touchdowns_sustained: mts.sum(:conceded),
      casualties_made: mts.sum { |mt| mt.api_data&.dig("inflictedcasualties") || 0 },
      casualties_sustained: mts.sum { |mt| mt.api_data&.dig("sustainedcasualties") || 0 }
    )
    stat
  end

  private

  def roster_match_players(statuses)
    MatchPlayer
      .where(player: players.where(status: statuses))
      .newest_first
      .includes(:match, player: :team)
      .to_a
      .group_by(&:player_id)
      .map { |_player_id, versions| versions.first }
      .sort_by { |version| [version.player.number || Float::INFINITY, version.player.name.to_s.downcase] }
  end
end
