class SeriesTeam < ApplicationRecord
  belongs_to :series
  belongs_to :team
end
