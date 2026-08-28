require "test_helper"

class HighlightTest < ActiveSupport::TestCase
  def new_format_json
    {
      "teams" => {
        "home" => {
          "id" => "t001", "name" => "Cackling Furies", "team_value" => 1650,
          "players" => {
            "1" => { "name" => "Ilona 'The Queen'", "kind" => "Black Orc", "skills" => ["Guard"], "status" => "normal" },
            "2" => { "name" => "Trinity 'The Rookie'", "kind" => "Goblin", "skills" => ["Stunty"], "status" => "injured" }
          }
        },
        "away" => {
          "id" => "t002", "name" => "Razorback Raiders", "team_value" => 1700,
          "players" => {
            "37" => { "name" => "Ratty", "kind" => "Skaven Blitzer", "skills" => ["Block"], "status" => "normal" }
          }
        }
      }
    }
  end

  test "record_match_players! creates highlights from JSON" do
    match = matches(:season_opener)
    json = new_format_json
    json["highlights"] = [
      { "event" => "touch_down", "player_id" => "1", "turn" => 3, "team" => "home" },
      { "event" => "injury_caused", "injured_player_id" => "37", "injury_type" => "knocked_out", "injury_detail" => "Concussion" }
    ]

    match.record_match_players!(json)

    assert_equal 2, match.highlights.count

    td = match.highlights.touchdowns.first
    assert_equal "touch_down", td.event
    assert_equal 3, td.turn
    assert_equal "home", td.team
    assert_equal match.match_players.find_by(name: "Ilona 'The Queen'"), td.match_player
    assert_equal json["highlights"][0], td.data

    injury = match.highlights.injuries.first
    assert_equal "injury_caused", injury.event
    assert_equal match.match_players.find_by(name: "Ratty"), injury.injured_match_player
    assert_nil injury.match_player
  end

  test "record_match_players! links both acting and injured match players" do
    match = matches(:season_opener)
    json = new_format_json
    json["highlights"] = [
      { "event" => "injury_caused", "player_id" => "1", "injured_player_id" => "37", "injury_type" => "mng", "injury_detail" => "Fractured Arm" }
    ]

    match.record_match_players!(json)

    h = match.highlights.first
    assert_equal match.match_players.find_by(name: "Ilona 'The Queen'"), h.match_player
    assert_equal match.match_players.find_by(name: "Ratty"), h.injured_match_player
  end

  test "record_match_players! clears旧highlights on reprocess" do
    match = matches(:season_opener)
    json = new_format_json
    json["highlights"] = [
      { "event" => "touch_down", "player_id" => "1", "turn" => 3, "team" => "home" }
    ]

    match.record_match_players!(json)
    assert_equal 1, match.highlights.count

    json["highlights"] = [
      { "event" => "touch_down", "player_id" => "1", "turn" => 5, "team" => "home" },
      { "event" => "touch_down", "player_id" => "1", "turn" => 8, "team" => "home" }
    ]

    match.record_match_players!(json)
    assert_equal 2, match.highlights.count
    assert_equal [5, 8], match.highlights.pluck(:turn).sort
  end

  test "key_highlights returns touchdowns" do
    match = matches(:season_opener)
    json = new_format_json
    json["highlights"] = [
      { "event" => "touch_down", "player_id" => "1", "turn" => 3, "team" => "home" },
      { "event" => "injury_caused", "injured_player_id" => "37", "injury_type" => "knocked_out" },
      { "event" => "touch_down", "player_id" => "37", "turn" => 7, "team" => "away" }
    ]

    match.record_match_players!(json)

    assert_equal 2, match.key_highlights.count
    assert match.key_highlights.all? { |h| h.event == "touch_down" }
  end

  test "highlights scope filters by event" do
    match = matches(:season_opener)
    json = new_format_json
    json["highlights"] = [
      { "event" => "touch_down", "player_id" => "1", "turn" => 3 },
      { "event" => "injury_caused", "injured_player_id" => "2", "injury_type" => "dead" },
      { "event" => "knocked_out", "player_id" => "1", "turn" => 4 }
    ]

    match.record_match_players!(json)

    assert_equal 1, match.highlights.touchdowns.count
    assert_equal 1, match.highlights.injuries.count
    assert_equal 1, match.highlights.by_event("knocked_out").count
  end

  test "highlights without player_id still save" do
    match = matches(:season_opener)
    json = new_format_json
    json["highlights"] = [
      { "event" => "turn_over", "turn" => 2, "team" => "home" }
    ]

    match.record_match_players!(json)

    h = match.highlights.first
    assert_equal "turn_over", h.event
    assert_nil h.match_player
  end

  test "match has many highlights" do
    match = matches(:season_opener)
    json = new_format_json
    json["highlights"] = [
      { "event" => "touch_down", "player_id" => "1", "turn" => 3 }
    ]

    match.record_match_players!(json)

    assert_includes match.match_players.first.highlights, match.highlights.first
  end

  test "injured_match_player association works" do
    match = matches(:season_opener)
    json = new_format_json
    json["highlights"] = [
      { "event" => "injury_caused", "injured_player_id" => "2", "injury_type" => "mng", "injury_detail" => "Broken Ribs" }
    ]

    match.record_match_players!(json)

    injured_mp = match.match_players.find_by(name: "Trinity 'The Rookie'")
    assert_includes injured_mp.injury_highlights, match.highlights.first
  end

  test "target_player_name returns injured player for injury_caused" do
    match = matches(:season_opener)
    json = new_format_json
    json["highlights"] = [
      { "event" => "injury_caused", "injured_player_id" => "2", "injury_type" => "mng", "injury_detail" => "Broken Ribs" }
    ]

    match.record_match_players!(json)

    assert_equal "Trinity 'The Rookie'", match.highlights.first.target_player_name
  end

  test "target_player_name returns receiver for kick events" do
    match = matches(:season_opener)
    json = new_format_json
    json["highlights"] = [
      { "event" => "kick", "player_id" => "1", "received_by" => { "player_id" => "37", "player_name" => "Ratty", "team" => "away" } }
    ]

    match.record_match_players!(json)

    assert_equal "Ratty", match.highlights.first.target_player_name
  end

  test "target_player_name returns recoverer for loss_of_ball events" do
    match = matches(:season_opener)
    json = new_format_json
    json["highlights"] = [
      { "event" => "loss_of_ball", "player_id" => "1", "recovered_by" => { "player_id" => "37", "player_name" => "Ratty", "team" => "away" } }
    ]

    match.record_match_players!(json)

    assert_equal "Ratty", match.highlights.first.target_player_name
  end

  test "target_player_name returns nil when no target exists" do
    match = matches(:season_opener)
    json = new_format_json
    json["highlights"] = [
      { "event" => "move_ball", "player_id" => "1", "from" => { "x" => 1, "y" => 2 }, "to" => { "x" => 3, "y" => 4 } }
    ]

    match.record_match_players!(json)

    assert_nil match.highlights.first.target_player_name
  end
end
