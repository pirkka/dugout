require "test_helper"

class CompetitionsControllerTest < ActionDispatch::IntegrationTest
  test "centers numeric standings cells and shows team value" do
    teams(:cackling_furies).update!(value: 1234)
    teams(:razorback_raiders).update!(value: 2345)
    match = matches(:final_showdown)
    match.match_teams.create!(team: teams(:cackling_furies), score: 1, conceded: 0)
    match.match_teams.create!(team: teams(:razorback_raiders), score: 0, conceded: 1)

    get competition_path(competitions(:rebell_season_15))

    assert_response :success
    assert_select "thead th", text: "Team Value"
    assert_select "tbody td", text: "1234"
    assert_select "tbody td", text: "2345"
    assert_select "tbody tr td[style*='text-align: center']", count: 22
  end

  test "groups matches by round with headings" do
    match = matches(:final_showdown)
    match.match_teams.create!(team: teams(:cackling_furies), score: 1, conceded: 0)
    match.match_teams.create!(team: teams(:razorback_raiders), score: 0, conceded: 1)

    get competition_path(competitions(:rebell_season_15))
    assert_response :success
    assert_select "h3", text: "Round 1"
    assert_select "h3", text: "Round 2"
  end

  test "renders round TBD heading when no matches have rounds" do
    match = matches(:final_showdown)
    match.match_teams.create!(team: teams(:cackling_furies), score: 1, conceded: 0)
    match.match_teams.create!(team: teams(:razorback_raiders), score: 0, conceded: 1)
    competition = competitions(:rebell_season_15)
    competition.matches.update_all(round: nil)
    contests(:upcoming_round_1).destroy

    get competition_path(competition)
    assert_response :success
    assert_select "h3", text: "Round TBD"
  end

  test "renders schedule with upcoming matches" do
    match = matches(:final_showdown)
    match.match_teams.create!(team: teams(:cackling_furies), score: 1, conceded: 0)
    match.match_teams.create!(team: teams(:razorback_raiders), score: 0, conceded: 1)

    get competition_path(competitions(:rebell_season_15))
    assert_response :success
    assert_select "h2", text: "Schedule"
    assert_select "h3", text: "Round 3"
    assert_select "li", text: /August 20, 2026:/
    assert_select "li", text: /Cackling Furies/
    assert_select "li", text: /Razorback Raiders/
    assert_select "li", text: /TBA/, count: 0
  end

  test "refresh calls refresh_upcoming_matches" do
    upcoming_called = false
    original_teams = Competition.instance_method(:refresh_teams)
    Competition.define_method(:refresh_teams) { true }
    original_upcoming = Competition.instance_method(:refresh_upcoming_matches)
    Competition.define_method(:refresh_upcoming_matches) { upcoming_called = true; true }
    original_matches = Competition.instance_method(:refresh_matches)
    Competition.define_method(:refresh_matches) { true }
    original_standings = Competition.instance_method(:refresh_standings)
    Competition.define_method(:refresh_standings) { true }

    post refresh_competition_path(competitions(:rebell_season_15))
    assert_redirected_to competition_path(competitions(:rebell_season_15))
    assert upcoming_called
  ensure
    Competition.define_method(:refresh_teams, original_teams)
    Competition.define_method(:refresh_upcoming_matches, original_upcoming)
    Competition.define_method(:refresh_matches, original_matches)
    Competition.define_method(:refresh_standings, original_standings)
  end
end
