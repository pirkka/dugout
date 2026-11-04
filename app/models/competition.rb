class Competition < ApplicationRecord
  belongs_to :league
  belongs_to :series, optional: true
  has_many :competition_teams, -> { order(position: :asc) }, dependent: :destroy
  has_many :teams, through: :competition_teams
  has_many :matches, dependent: :destroy
  has_many :contests, dependent: :destroy

  enum :platform, { pc: 0, playstation: 1, xbox: 2 }
  enum :format, { round_robin: 0, single_elimination: 1, ladder: 2, swiss: 3 }
  enum :status, { upcoming: 0, active: 1, finished: 2 }

  def to_param
    slug
  end

  def game_version
    self.league.game_version
  end

  def active?
    return true if contests.any?
    matches.where("started > ?", 30.days.ago).exists?
  end

  def compute_status!(had_api_contests: false)
    new_status = if active?
      :active
    elsif had_api_contests || !matches.empty?
      :finished
    else
      :upcoming
    end
    update!(status: new_status)
  end

  def refresh_matches
    client = CyanideApi::Client.new
    data = client.matches(competition_name: name, competition_id: api_id, league_id: league.api_id, platform: platform, game_version: league.game_version)
    api_matches = data["matches"] || []

    contest_rounds = {}
    if league.game_version.to_sym == :bb3
      client.contests(league_id: league.api_id, competition_id: api_id, game_version: league.game_version).fetch("contests", []).each do |contest|
        contest_rounds[contest["game_id"].to_s] ||= contest["competition_round"] || contest["round"]
      end
    end

    api_matches.each do |m|
      match = matches.find_or_create_by!(api_id: m["uuid"].to_s)
      contest_round = contest_rounds[m["uuid"].to_s]
      round = contest_round && contest_round.to_i > 0 ? contest_round : m["round"]
      match.update!(started: m["started"], finished: m["finished"], round: round, api_data: m)
      api_teams = m["teams"] || []
      home = true
      api_teams.each do |t|
        team = Team.find_by(api_id: t["idteamlisting"])
        next unless team
        opponent = api_teams.find { |ot| ot["idteamlisting"] != t["idteamlisting"] }
        mt = match.match_teams.find_or_create_by!(team: team)
        goals_scored = t["score"] || 0
        goals_conceded = opponent&.dig("score") || 0
        result = if goals_scored > goals_conceded
          :win
        elsif goals_scored < goals_conceded
          :loss
        else
          :draw
        end
        mt.update!(home: home, result: result, score: goals_scored, conceded: goals_conceded, api_data: t)
        home = !home # the first team is home, the second is away
      end
      # calculate and save the match_hash
      match.reload
      match_hash = match.calculate_match_hash
      match.update!(match_hash: match_hash)
    end
    remove_duplicate_matches unless ladder?
    refresh_standings if league.game_version.to_sym == :bb3
    calculate_standings if league.game_version.to_sym == :bb2
    calculate_team_stats
    recalculate_lifetime_stats
    true
  rescue CyanideApi::NotFoundError
    errors.add(:base, "Matches not found on API")
    false
  rescue CyanideApi::Error => e
    errors.add(:base, e.message)
    false
  end

  def refresh_upcoming_matches
    return false if ladder?
    client = CyanideApi::Client.new
    data = client.contests(
      league_name: league.name,
      competition_name: name,
      league_id: league.api_id,
      competition_id: api_id,
      game_version: league.game_version,
      status: "*"
    )
    api_contests = data["contests"] || data["upcoming_matches"] || []
    had_any_contests = api_contests.any?

    upcoming_ids = []
    api_contests.each do |c|
      contest_status = c["contest_status"] || c["status"]
      next if contest_status.to_s.downcase.in?(%w[played validated])
      # game_id is the played-match uuid on BB3 (match_uuid on BB2);
      # match_id is the contest-level id and never matches matches.api_id.
      match_api_id = c["game_id"].presence || c["match_uuid"].presence
      next if match_api_id.present? && matches.exists?(api_id: match_api_id.to_s)
      next if api_id.present? && c["competition_id"].to_s != api_id
      upcoming_ids << c["contest_id"].to_s
      contest = contests.find_or_initialize_by(api_id: c["contest_id"].to_s)
      opponents = c["opponents"] || []
      contest.update!(
        match_id: c["match_id"]&.to_s,
        round: c["competition_round"] || c["round"],
        status: contest_status,
        match_date: c["match_date"],
        live: c["live"].to_i == 1,
        home_team: team_for_contest(opponents[0]),
        away_team: team_for_contest(opponents[1]),
        api_data: c
      )
    end

    if api_contests.any?
      contests.where.not(api_id: upcoming_ids).destroy_all
    end
    had_any_contests
  rescue CyanideApi::NotFoundError
    errors.add(:base, "Upcoming matches not found on API")
    false
  rescue CyanideApi::Error => e
    errors.add(:base, e.message)
    false
  end

  def refresh_teams
    client = CyanideApi::Client.new
    data = client.teams(competition_name: name, competition_id: api_id, league_id: league.api_id, platform: platform, game_version: league.game_version)
    api_teams = data["teams"] || []
    api_teams.each do |t|
      team = Team.find_or_create_by!(api_id: t["id"].to_s) do |new_team|
        new_team.name = t["team"]
        new_team.slug = t["team"].parameterize
      end
      attributes = {
        name: t["team"],
        slug: t["team"].parameterize,
        logo: t["logo"],
        race: t["race"],
        slogan: t["description"],
        rerolls: t["rerolls"],
        apothecary: t["apothecary"],
        assistant_coaches: t["assistant_coaches"] || t["coach_assistants"],
        cheerleaders: t["cheerleaders"],
        api_data: t
      }
      attributes[:value] = t["value"] if t.key?("value")
      attributes[:cash] = t["cash"] if t.key?("cash")
      attributes[:popularity] = t["popularity"] || t["dedicated_fans"] if t.key?("popularity") || t.key?("dedicated_fans")
      team.update!(attributes)
      competition_teams.find_or_create_by!(team: team)
    end

    true
  rescue CyanideApi::NotFoundError
    errors.add(:base, "Teams not found on API")
    false
  rescue CyanideApi::Error => e
    errors.add(:base, e.message)
    false
  end

  def remove_duplicate_matches
    grouped = matches.includes(:match_teams).group_by do |match|
      match.match_teams.map(&:team_id).sort
    end

    grouped.each_value do |group|
      next if group.size <= 1
      keeper = group.max_by { |m| m.started || Time.at(0) }
      (group - [keeper]).each(&:destroy)
    end
  end

  def refresh_standings
    Rails.logger.debug "👀 Refreshing standings for competition #{name} (#{api_id}) "
    client = CyanideApi::Client.new
    data = client.ladder(competition_id: api_id, game_version: league.game_version)
    api_rankings = data["ranking"] || []

    api_rankings.each do |entry|
      team_data = entry["team"]
      team = Team.find_by(api_id: team_data["id"])
      next unless team
      ct = competition_teams.find_by(team: team)
      next unless ct
      wdl = team_data["w/d/l"].split("/").map(&:to_i)
      wins, draws, losses = wdl[0], wdl[1], wdl[2]
      matches_played = wins + draws + losses
      points = wins * 3 + draws
      score = entry["score"]
      tv = team_data["tv"]
      team.update_column(:value, tv) if tv.present? && team.value != tv
      ct.update!(matches: matches_played, wins: wins, draws: draws, losses: losses, points: points, score: score, position: team_data["rank"], api_data: entry)
    end
    true
  rescue CyanideApi::NotFoundError
    errors.add(:base, "Ladder not found on API")
    false
  rescue CyanideApi::Error => e
    errors.add(:base, e.message)
    false
  end

  def calculate_team_stats
    competition_teams.each do |ct|
      mts = MatchTeam.joins(:match).where(matches: { competition_id: id }, team_id: ct.team_id)
      touchdowns_made = mts.sum(:score)
      touchdowns_sustained = mts.sum(:conceded)
      casualties_made = mts.sum { |mt| mt.api_data&.dig("inflictedcasualties") || 0 }
      casualties_sustained = mts.sum { |mt| mt.api_data&.dig("sustainedcasualties") || 0 }
      ct.update!(touchdowns_made: touchdowns_made, touchdowns_sustained: touchdowns_sustained, casualties_made: casualties_made, casualties_sustained: casualties_sustained)
    end
  end

  def recalculate_lifetime_stats
    competition_teams.select(:team_id).distinct.pluck(:team_id).each do |team_id|
      Team.find_by(id: team_id)&.recalculate_lifetime_stats!
    end
  end

  # Total rounds for a round-robin: every team plays every other team once.
  # Returns nil for formats where the round count can't be derived (the
  # Cyanide API only publishes the current round's contests, and future
  # round pairings are drawn per round, so rounds beyond the known ones
  # are shown as TBD rather than projected).
  def expected_rounds
    return nil unless round_robin?
    count = competition_teams.count
    return nil if count < 2
    count.even? ? count - 1 : count
  end

  # Whole schedule skeleton: every round from 1 to the highest known or
  # expected round, with played matches and upcoming/live contests attached.
  # Rounds with neither are future rounds whose pairings don't exist yet.
  def schedule
    by_round = Hash.new { |h, k| h[k] = { matches: [], contests: [] } }
    matches.each { |m| by_round[m.round][:matches] << m }
    contests.order(:match_date).each { |c| by_round[c.round][:contests] << c }
    last = [(by_round.keys.compact.max || 0), (expected_rounds || 0)].max
    return [] if last < 1
    rows = (1..last).map do |round|
      entry = by_round[round]
      entry[:matches].sort_by! { |m| -(m.started || Time.at(0)).to_f }
      [round, entry]
    end
    rows << [nil, by_round[nil]] if by_round.key?(nil)
    rows
  end

  def calculate_standings
    standings = competition_teams.map do |ct|
      mts = MatchTeam.joins(:match).where(matches: { competition_id: id }, team_id: ct.team_id)
      wins = mts.win.count
      draws = mts.draw.count
      losses = mts.loss.count
      matches_played = wins + draws + losses
      points = wins * 3 + draws
      { ct: ct, matches: matches_played, wins: wins, draws: draws, losses: losses, points: points }
    end

    standings.sort_by! { |s| [-s[:points], -s[:wins]] }

    standings.each_with_index do |s, i|
      s[:ct].update!(
        matches: s[:matches],
        wins: s[:wins],
        draws: s[:draws],
        losses: s[:losses],
        points: s[:points],
        position: i + 1
      )
    end
  end

  def cyanide_teams_uri
    api_key = Rails.application.credentials.cyanide_api_key
    game_version = league.game_version
    "https://web.cyanide-studio.com/ws/#{game_version}/teams/?key=#{api_key}&competition_id=#{api_id}"
  end

  private

  def team_for_contest(opponent)
    return nil unless opponent
    team_id = opponent.dig("team", "id") || opponent.dig("team", "idteamlisting")
    team_id ? Team.find_by(api_id: team_id.to_s) : nil
  end

  public

  def cyanide_standings_uri
    api_key = Rails.application.credentials.cyanide_api_key
    game_version = league.game_version
    numerical_game_version = game_version.gsub('bb', '').to_i
    "https://web.cyanide-studio.com/ws/#{game_version}/ladder/?key=#{api_key}&competition_id=#{api_id}&bb=#{numerical_game_version}"
  end

  def cyanide_matches_uri
    api_key = Rails.application.credentials.cyanide_api_key
    game_version = league.game_version
    "https://web.cyanide-studio.com/ws/#{game_version}/matches/?key=#{api_key}&competition_id=#{api_id}&start=1980-01-01"
  end

  def cyanide_contests_uri
    api_key = Rails.application.credentials.cyanide_api_key
    game_version = league.game_version
    "https://web.cyanide-studio.com/ws/#{game_version}/contests/?key=#{api_key}&league_id=#{league.api_id}&competition_id=#{api_id}&status=*&limit=1000"
  end

  def cyanide_coaches_uri
    api_key = Rails.application.credentials.cyanide_api_key
    game_version = league.game_version
    "https://web.cyanide-studio.com/ws/#{game_version}/coaches/?key=#{api_key}&league_id=#{league.api_id}&competition_id=#{api_id}&status=*&limit=1000"
  end
end
