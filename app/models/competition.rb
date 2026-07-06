class Competition < ApplicationRecord
  belongs_to :league
  belongs_to :series, optional: true
  has_many :competition_teams, -> { order(position: :asc) }, dependent: :destroy
  has_many :teams, through: :competition_teams
  has_many :matches, dependent: :destroy

  def to_param
    slug
  end

  enum :platform, { pc: 0, playstation: 1, xbox: 2 }
  enum :format, { round_robin: 0, single_elimination: 1, ladder: 2, swiss: 3 }

  def refresh_matches
    client = CyanideApi::Client.new
    data = client.matches(competition_name: name, competition_id: api_id, league_id: league.api_id, platform: platform, game_version: league.game_version)
    api_matches = data["matches"] || []

    api_matches.each do |m|
      match = matches.find_or_create_by!(api_id: m["uuid"].to_s)
      match.update!(started: m["started"], finished: m["finished"], round: m["round"], api_data: m)

      api_teams = m["teams"] || []
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
        mt.update!(result: result, score: goals_scored, conceded: goals_conceded, api_data: t)
      end
    end
    remove_duplicate_matches if format != :ladder
    refresh_standings if league.game_version.to_sym == :bb3
    calculate_standings if league.game_version.to_sym == :bb2
    calculate_team_stats
    true
  rescue CyanideApi::NotFoundError
    errors.add(:base, "Matches not found on API")
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
      team.update!(
        name: t["team"],
        slug: t["team"].parameterize,
        value: t["value"],
        cash: t["cash"],
        rerolls: t["rerolls"],
        apothecary: t["apothecary"],
        assistant_coaches: t["assistant_coaches"],
        cheerleaders: t["cheerleaders"],
        popularity: t["popularity"],
        logo: t["logo"],
        api_coach_id: t["coach_id"],
        api_data: t
      )
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
      ct.update!(matches: matches_played, wins: wins, draws: draws, losses: losses, points: points, position: team_data["rank"], api_data: entry)
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
