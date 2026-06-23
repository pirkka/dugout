require "test_helper"

class MatchTest < ActiveSupport::TestCase
  test "belongs to competition" do
    match = matches(:season_opener)
    assert_equal competitions(:rebell_season_15), match.competition
  end

  test "has many teams through match_teams" do
    match = matches(:season_opener)
    assert_equal 2, match.teams.count
    assert_includes match.teams, teams(:cackling_furies)
    assert_includes match.teams, teams(:razorback_raiders)
  end

  test "stores timing fields" do
    match = matches(:season_opener)
    assert_equal Time.zone.parse("2026-06-01 19:00:00"), match.started
    assert_equal Time.zone.parse("2026-06-01 20:30:00"), match.finished
    assert_equal 1, match.round
  end
end
