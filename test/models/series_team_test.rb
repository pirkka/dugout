require "test_helper"

class SeriesTeamTest < ActiveSupport::TestCase
  test "belongs to a series" do
    series_team = series_teams(:rebbl_season_15_cackling_furies)
    assert_equal series(:rebbl_season_15), series_team.series
  end

  test "belongs to a team" do
    series_team = series_teams(:rebbl_season_15_cackling_furies)
    assert_equal teams(:cackling_furies), series_team.team
  end
end
