class Competition < ApplicationRecord
  belongs_to :league
  has_many :competition_teams, dependent: :destroy
  has_many :teams, through: :competition_teams
  has_many :matches, dependent: :destroy

  def to_param
    slug
  end

  enum :platform, { pc: 0, playstation: 1, xbox: 2 }
  enum :format, { round_robin: 0, single_elimination: 1, ladder: 2, swiss: 3 }

  def refresh_matches
    client = CyanideApi::Client.new
    data = client.matches(competition_name: name, competition_id: api_id, league_id: league.api_id, platform: platform)
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
        mt.update!(score: t["score"], conceded: opponent&.dig("score"), api_data: t)
      end
    end

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
    data = client.teams(competition_name: name, competition_id: api_id, league_id: league.api_id, platform: platform)
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
        coach_id: t["coach_id"],
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
end
