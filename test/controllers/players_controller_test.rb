require "test_helper"

class PlayersControllerTest < ActionDispatch::IntegrationTest
  test "shows player match history newest first" do
    player = Player.create!(team: teams(:cackling_furies), number: 1, name: "Ilona 'The Queen'")
    MatchPlayer.create!(player: player, match: matches(:season_opener), name: "Ilona", number: 1, kind: "Black Orc", skills: ["Guard"], status: "normal", team_value: 1500)
    MatchPlayer.create!(player: player, match: matches(:final_showdown), name: "Ilona", number: 1, kind: "Black Orc", skills: ["Guard", "Block"], status: "injured", injury_type: "mng", team_value: 1650)

    get player_path(player)
    assert_response :success
    assert_select "h1", text: /Ilona 'The Queen'/
    assert_select "tbody tr", count: 2
    assert_select "td", text: "Guard, Block"
    assert_select "td", text: "mng"
    assert response.body.index("June 15, 2026") < response.body.index("June 01, 2026")
  end

  test "shows team link and status badge" do
    player = Player.create!(team: teams(:cackling_furies), number: 1, name: "Ilona 'The Queen'")

    get player_path(player)
    assert_response :success
    assert_select "h1", text: /active/
    assert_select "a[href=?]", team_path(teams(:cackling_furies)), text: "Cackling Furies"
  end

  test "shows no match history message when empty" do
    player = Player.create!(team: teams(:cackling_furies), number: 1, name: "Ilona 'The Queen'")

    get player_path(player)
    assert_response :success
    assert_select "p", text: "No match history yet."
  end

  test "renders 404 for unknown player" do
    get player_path(999999)
    assert_response :not_found
  end
end
