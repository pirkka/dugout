require "test_helper"

class SeriesTest < ActiveSupport::TestCase
  test "belongs to a league" do
    series = series(:rebbl_season_15)
    assert_equal leagues(:rebell), series.league
  end

  test "has many competitions" do
    series = series(:rebbl_season_15)
    assert_respond_to series, :competitions
  end

  test "destroying series nullifies competition references" do
    series = series(:rebbl_season_15)
    competition = competitions(:rebell_season_15)
    competition.update!(series: series)
    series.destroy
    assert_nil competition.reload.series
  end
end
