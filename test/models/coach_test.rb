require "test_helper"

class CoachTest < ActiveSupport::TestCase
  test "has many teams" do
    coach = coaches(:furies_coach)
    assert_respond_to coach, :teams
  end

  test "destroying coach nullifies team references" do
    coach = coaches(:furies_coach)
    team = teams(:cackling_furies)
    team.update!(coach: coach)
    coach.destroy
    assert_nil team.reload.coach
  end
end
