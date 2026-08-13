require "test_helper"

class TeamTest < ActiveSupport::TestCase
  test "upcoming_contests returns contests where the team is home or away" do
    team = teams(:cackling_furies)
    away = teams(:razorback_raiders)
    competition = competitions(:rebell_season_15)
    home_contest = contests(:upcoming_round_1)
    away_contest = competition.contests.create!(api_id: "cn-away", match_id: "mc-away", round: 4, status: "Scheduled", away_team: team)
    other = competition.contests.create!(api_id: "cn-other", match_id: "mc-other", round: 5, status: "Scheduled")

    assert_equal [home_contest, away_contest], team.upcoming_contests
    assert_equal [home_contest], away.upcoming_contests
    refute_includes team.upcoming_contests, other
  end

  test "upcoming_contests excludes contests from other competitions" do
    team = teams(:cackling_furies)
    other_comp = leagues(:xfactor).competitions.create!(name: "Other Cup", slug: "other-cup", format: :round_robin, platform: :pc)
    other_comp.contests.create!(api_id: "cn-other-comp", match_id: "mc-oc", round: 1, status: "Scheduled", home_team: team)

    assert_equal [contests(:upcoming_round_1)], team.upcoming_contests
  end
end
