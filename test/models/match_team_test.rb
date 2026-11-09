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

  test "casualty helpers coerce string values from the API" do
    mt = match_teams(:one_home)
    mt.api_data = { "inflictedcasualties" => "3", "sustainedcasualties" => "1" }

    assert_equal 3, mt.inflicted_casualties
    assert_equal 1, mt.sustained_casualties
  end

  test "casualty helpers default to zero when api data is missing" do
    mt = match_teams(:one_home)
    mt.api_data = nil

    assert_equal 0, mt.inflicted_casualties
    assert_equal 0, mt.sustained_casualties
  end
end
