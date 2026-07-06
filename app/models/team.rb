class Team < ApplicationRecord
  belongs_to :coach, optional: true
  has_many :competition_teams, dependent: :destroy
  has_many :competitions, through: :competition_teams
  has_many :series_teams, dependent: :destroy
  has_many :series, through: :series_teams
  has_many :match_teams, dependent: :destroy
  has_many :matches, through: :match_teams

  def to_param
    slug
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
    self.slug = data["team"].parameterize
    self.value = data["value"]
    self.cash = data["cash"]
    self.rerolls = data["rerolls"]
    self.apothecary = data["apothecary"]
    self.assistant_coaches = data["assistant_coaches"]
    self.cheerleaders = data["cheerleaders"]
    self.popularity = data["popularity"]
    self.logo = data["logo"]
    # find or create coach
    coach = Coach.find_or_create_by!(api_id: data["coach"]["id"].to_s) do |new_coach|
      new_coach.name = data["coach"]["name"]
      new_coach.slug = data["coach"]["name"].parameterize
    end
    coach.update!(
      name: data["coach"]["name"],
      slug: data["coach"]["name"].parameterize,
      api_data: data["coach"]
    )
    self.coach = coach
  end

  def cyanide_uri
    api_key = Rails.application.credentials.cyanide_api_key
    game_version = self.competitions.first.league.game_version
    "https://web.cyanide-studio.com/ws/#{game_version}/team/?key=#{api_key}&id=#{api_id}&stats=1"
  end
end
