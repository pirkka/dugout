class Match < ApplicationRecord
  belongs_to :competition
  has_many :match_teams, dependent: :destroy
  has_many :teams, through: :match_teams


  def cyanide_match_uri
    api_key = Rails.application.credentials.cyanide_api_key
    game_version = competition.league.game_version
    "https://web.cyanide-studio.com/ws/#{game_version}/match/?key=#{api_key}&match_id=#{api_id}&start=1980-01-01"
  end
end
