require "test_helper"

class TeamsControllerTest < ActionDispatch::IntegrationTest
  test "shows upcoming matches for the team" do
    get team_path(teams(:cackling_furies))
    assert_response :success
    assert_select "h2", text: "Upcoming Matches"
    assert_select "li", text: /August 20, 2026:/
    assert_select "li", text: /Cackling Furies vs/
  end

  test "shows no upcoming matches message when none" do
    teams(:cackling_furies).competitions.each { |c| c.contests.destroy_all }

    get team_path(teams(:cackling_furies))
    assert_response :success
    assert_select "p", text: "No upcoming matches."
  end
end
