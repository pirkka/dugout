class League < ApplicationRecord
  has_many :competitions

  def to_param
    slug
  end

  enum :platform, { pc: 0, playstation: 1, xbox: 2 }

  FORMAT_MAP = {
    "RoundRobin" => :round_robin,
    "Knockout" => :single_elimination,
    "Ladder" => :ladder,
    "Wissen" => :swiss
  }.freeze

  def refresh_from_api
    client = CyanideApi::Client.new
    data = client.league(id: api_id)
    update!(
      name: data['league']['name'],
      slug: data['league']['name'].parameterize,
      api_id: data['league']['id'] || api_id,
      api_data: data
    )
    refresh_competitions
    competitions.each(&:refresh_matches)
    true
  rescue CyanideApi::NotFoundError
    errors.add(:base, "League not found on API")
    false
  rescue ::CyanideApi::Error => e
    errors.add(:base, e.message)
    false
  end

  def refresh_competitions
    client = ::CyanideApi::Client.new
    data = client.competitions(league_id: api_id, league_name: name, platform: platform)
    api_competitions = data["competitions"] || []

    api_competitions.each do |comp|
      competition = competitions.find_or_initialize_by(api_id: comp["id"].to_s)
      competition.update!(
        name: comp["name"],
        slug: comp["name"].parameterize,
        format: FORMAT_MAP.fetch(comp["format"], :round_robin),
        platform: self.platform,
        api_data: comp
      )
    end

    true
  rescue CyanideApi::NotFoundError
    errors.add(:base, "Competitions not found on API")
    false
  rescue CyanideApi::Error => e
    errors.add(:base, e.message)
    false
  end
end
