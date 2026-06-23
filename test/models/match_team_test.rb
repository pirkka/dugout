require "test_helper"

class MatchTeamTest < ActiveSupport::TestCase
  test "belongs to match" do
    mt = match_teams(:one_home)
    assert_equal matches(:season_opener), mt.match
  end

  test "belongs to team" do
    mt = match_teams(:one_home)
    assert_equal teams(:cackling_furies), mt.team
  end

  test "stores score and conceded" do
    mt = match_teams(:one_home)
    assert_equal 2, mt.score
    assert_equal 1, mt.conceded
  end
end
