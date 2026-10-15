class TeamLifetimeStat < ApplicationRecord
  belongs_to :team

  def touchdown_diff
    touchdowns_made.to_i - touchdowns_sustained.to_i
  end

  def casualty_diff
    casualties_made.to_i - casualties_sustained.to_i
  end
end
