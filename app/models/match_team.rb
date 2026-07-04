class MatchTeam < ApplicationRecord
  belongs_to :match
  belongs_to :team

  enum :result, { win: 0, loss: 1, draw: 2 }
end
