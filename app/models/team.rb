class Team < ApplicationRecord
  has_many :competition_teams, dependent: :destroy
  has_many :competitions, through: :competition_teams
  has_many :series_teams, dependent: :destroy
  has_many :series, through: :series_teams
  has_many :match_teams, dependent: :destroy
  has_many :matches, through: :match_teams

  def to_param
    slug
  end
end
