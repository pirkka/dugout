class League < ApplicationRecord
  has_many :series, dependent: :destroy
  has_many :competitions

  def to_param
    slug
  end

  enum :platform, { pc: 0, playstation: 1, xbox: 2 }
  enum :game_version, { bb1: 0, bb2: 1, bb3: 2 }

  FORMAT_MAP = {
    "RoundRobin" => :round_robin,
    "Knockout" => :single_elimination,
    "Ladder" => :ladder,
    "Wissen" => :swiss
  }.freeze

  def refresh_from_api
    client = CyanideApi::Client.new
    data = client.league(id: api_id, game_version: game_version)
    league_data = data&.dig('league')
    unless league_data
      errors.add(:base, "Invalid API response")
      return false
    end
    update!(
      name: league_data['name'],
      slug: league_data['name'].parameterize,
      api_id: league_data['id'] || api_id,
      api_data: data
    )
    refresh_competitions
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
    data = client.competitions(league_id: api_id, league_name: name, platform: platform, game_version: game_version)
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

  def cyanide_uri
    api_key = Rails.application.credentials.cyanide_api_key
    game_number = game_version.gsub('bb', '')
    "https://web.cyanide-studio.com/ws/#{game_version}/league/?key=#{api_key}&league=#{api_id}&bb=#{game_number}"
  end
end
