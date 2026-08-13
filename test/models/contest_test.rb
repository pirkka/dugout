require "test_helper"

class ContestTest < ActiveSupport::TestCase
  test "belongs to competition and optional teams" do
    contest = contests(:upcoming_round_1)
    assert_equal competitions(:rebell_season_15), contest.competition
    assert_equal teams(:cackling_furies), contest.home_team
    assert_equal teams(:razorback_raiders), contest.away_team
  end

  test "allows contests without teams" do
    contest = Contest.new(competition: competitions(:rebell_season_15), api_id: "cn-x", status: "Scheduled")
    assert contest.valid?
  end
end
