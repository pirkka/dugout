class Contest < ApplicationRecord
  belongs_to :competition
  belongs_to :home_team, class_name: "Team", optional: true
  belongs_to :away_team, class_name: "Team", optional: true
end
