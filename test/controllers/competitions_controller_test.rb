require "test_helper"

class CompetitionsControllerTest < ActionDispatch::IntegrationTest
  test "groups matches by round with headings" do
    match = matches(:final_showdown)
    match.match_teams.create!(team: teams(:cackling_furies), score: 1, conceded: 0)
    match.match_teams.create!(team: teams(:razorback_raiders), score: 0, conceded: 1)

    get competition_path(competitions(:rebell_season_15))
    assert_response :success
    assert_select "h3", text: "Round 1"
    assert_select "h3", text: "Round 2"
  end

  test "renders flat list without round headings when no matches have rounds" do
    match = matches(:final_showdown)
    match.match_teams.create!(team: teams(:cackling_furies), score: 1, conceded: 0)
    match.match_teams.create!(team: teams(:razorback_raiders), score: 0, conceded: 1)
    competition = competitions(:rebell_season_15)
    competition.matches.update_all(round: nil)

    get competition_path(competition)
    assert_response :success
    assert_select "h3", count: 0
  end
end
