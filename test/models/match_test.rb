require "test_helper"

class MatchTest < ActiveSupport::TestCase
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

  def old_format_json
    {
      "info" => {
        "teams" => {
          "0" => { "coach_name" => "Coach A", "name" => "Cackling Furies", "race" => 12 },
          "1" => { "coach_name" => "Coach B", "name" => "Razorback Raiders", "race" => 5, "score" => 1 }
        },
        "players" => {
          "1" => { "name" => "Ilona 'The Queen'", "number" => 1, "player_type" => 14, "team" => "0" },
          "43" => { "name" => "Ratty", "number" => 7, "player_type" => 3, "team" => "1" }
        }
      }
    }
  end
  test "belongs to competition" do
    match = matches(:season_opener)
    assert_equal competitions(:rebell_season_15), match.competition
  end

  test "has many teams through match_teams" do
    match = matches(:season_opener)
    assert_equal 2, match.teams.count
    assert_includes match.teams, teams(:cackling_furies)
    assert_includes match.teams, teams(:razorback_raiders)
  end

  test "stores timing fields" do
    match = matches(:season_opener)
    assert_equal Time.zone.parse("2026-06-01 19:00:00"), match.started
    assert_equal Time.zone.parse("2026-06-01 20:30:00"), match.finished
    assert_equal 1, match.round
  end

  test "upload_replay_json stores parsed json" do
    match = matches(:season_opener)
    file = Rack::Test::UploadedFile.new("test/fixtures/replay.json", "application/json")
    assert match.upload_replay_json(file)
    assert_equal "main", match.replay_json.dig("info", "type")
  end

  test "upload_replay_json rejects invalid json" do
    match = matches(:season_opener)
    file = Tempfile.new(["bad", ".json"])
    file.write("not json")
    file.rewind
    refute match.upload_replay_json(file)
    assert match.errors[:replay_json].present?
  ensure
    file&.close
    file&.unlink
  end

  test "upload_replay_json returns false without file" do
    match = matches(:season_opener)
    refute match.upload_replay_json(nil)
  end

  test "upload_replay_jsons uploads files to matching matches" do
    match = matches(:season_opener)
    file = Rack::Test::UploadedFile.new("test/fixtures/replay.json", "application/json")
    result = Match.upload_replay_jsons([file])
    assert_equal({ uploaded: 1, skipped: 0 }, result)
    assert_equal "main", match.reload.replay_json.dig("info", "type")
  end

  test "upload_replay_jsons skips files without a matching match" do
    file = Tempfile.new(["unmatched", ".json"])
    file.write({ match_hash: "nope", info: { type: "main" } }.to_json)
    file.rewind
    result = Match.upload_replay_jsons([file])
    assert_equal({ uploaded: 0, skipped: 1 }, result)
  ensure
    file&.close
    file&.unlink
  end

  test "upload_replay_jsons skips invalid json" do
    file = Tempfile.new(["bad", ".json"])
    file.write("not json")
    file.rewind
    result = Match.upload_replay_jsons([file])
    assert_equal({ uploaded: 0, skipped: 1 }, result)
  ensure
    file&.close
    file&.unlink
  end

  test "upload_replay_jsons handles nil files" do
    assert_equal({ uploaded: 0, skipped: 0 }, Match.upload_replay_jsons(nil))
    assert_equal({ uploaded: 0, skipped: 0 }, Match.upload_replay_jsons([nil]))
  end

  test "record_match_players! creates match players from new format json" do
    match = matches(:season_opener)
    count = match.record_match_players!(new_format_json)

    assert_equal 3, count
    assert_equal 3, match.match_players.count

    home = match.match_players.find_by(name: "Ilona 'The Queen'")
    assert_equal teams(:cackling_furies), home.player.team
    assert_equal 1, home.number
    assert_equal "Black Orc", home.kind
    assert_equal ["Guard"], home.skills
    assert_equal "normal", home.status
    assert_equal 1650, home.team_value
    assert_equal "new", home.format

    away = match.match_players.find_by(name: "Ratty")
    assert_equal teams(:razorback_raiders), away.player.team
    assert_equal 1, away.number
  end

  test "record_match_players! creates match players from old format json with away offset" do
    match = matches(:season_opener)
    count = match.record_match_players!(old_format_json)

    assert_equal 2, count

    home = match.match_players.find_by(name: "Ilona 'The Queen'")
    assert_equal teams(:cackling_furies), home.player.team
    assert_equal 1, home.number
    assert_equal 14, home.player_type
    assert_equal "old", home.format

    away = match.match_players.find_by(name: "Ratty")
    assert_equal teams(:razorback_raiders), away.player.team
    assert_equal 7, away.number
  end

  test "record_match_players! replaces match players on reprocess" do
    match = matches(:season_opener)
    match.record_match_players!(new_format_json)
    match.record_match_players!(new_format_json)

    assert_equal 3, match.match_players.count
    assert_equal 3, match.reload.match_players.count
  end

  test "record_match_players! keeps player identity across matches" do
    match = matches(:season_opener)
    other = matches(:final_showdown)
    MatchTeam.create!(match: other, team: teams(:cackling_furies), home: true)
    MatchTeam.create!(match: other, team: teams(:razorback_raiders), home: false)

    match.record_match_players!(new_format_json)
    other.record_match_players!(new_format_json)

    ilona = Player.find_by(team: teams(:cackling_furies), name: "Ilona 'The Queen'")
    assert_equal 2, ilona.match_players.count
    assert_includes ilona.match_players.pluck(:match_id), other.id
  end

  test "record_match_players! captures the severest injury_type from highlights" do
    match = matches(:season_opener)
    json = new_format_json
    json["highlights"] = [
      { "event" => "injury_caused", "injured_player_id" => "2", "injury_type" => "knocked_out", "injury_detail" => "Concussion" },
      { "event" => "injury_caused", "injured_player_id" => "2", "injury_type" => "mng", "injury_detail" => "Fractured Arm" },
      { "event" => "touch_down", "player_id" => "1" }
    ]

    match.record_match_players!(json)

    injured = match.match_players.find_by(name: "Trinity 'The Rookie'")
    assert_equal Player::MNG, injured.injury_type
    assert_equal "Fractured Arm", injured.injury_detail
    assert_nil match.match_players.find_by(name: "Ilona 'The Queen'").injury_type
  end

  test "record_match_players! marks dead players with the highest priority" do
    match = matches(:season_opener)
    json = new_format_json
    json["highlights"] = [
      { "event" => "injury_caused", "injured_player_id" => "2", "injury_type" => "dead", "injury_detail" => "Skull fracture" },
      { "event" => "injury_caused", "injured_player_id" => "2", "injury_type" => "mng", "injury_detail" => "Fractured Arm" }
    ]

    match.record_match_players!(json)

    dead_player = match.match_players.find_by(name: "Trinity 'The Rookie'")
    assert_equal Player::DEAD, dead_player.injury_type
    assert_equal "Skull fracture", dead_player.injury_detail
  end

  test "record_match_players! handles renumbering across matches" do
    match = matches(:season_opener)
    other = matches(:final_showdown)
    MatchTeam.create!(match: other, team: teams(:cackling_furies), home: true)
    MatchTeam.create!(match: other, team: teams(:razorback_raiders), home: false)

    first = new_format_json
    first["teams"]["home"]["players"] = {
      "1" => { "name" => "Ilona 'The Queen'", "kind" => "Black Orc", "skills" => [], "status" => "normal" },
      "2" => { "name" => "Departed", "kind" => "Goblin", "skills" => [], "status" => "normal" },
      "3" => { "name" => "Jeffrey Dahmer", "kind" => "Goblin", "skills" => [], "status" => "normal" }
    }
    second = new_format_json
    second["teams"]["home"]["players"] = {
      "1" => { "name" => "Ilona 'The Queen'", "kind" => "Black Orc", "skills" => [], "status" => "normal" },
      "2" => { "name" => "Jeffrey Dahmer", "kind" => "Goblin", "skills" => ["Block"], "status" => "normal" },
      "3" => { "name" => "Newcomer", "kind" => "Goblin", "skills" => [], "status" => "normal" }
    }

    match.record_match_players!(first)
    other.record_match_players!(second)

    ilona = Player.find_by(team: teams(:cackling_furies), name: "Ilona 'The Queen'")
    assert_equal 2, ilona.match_players.count

    dahmer = Player.find_by(team: teams(:cackling_furies), name: "Jeffrey Dahmer")
    assert_equal 2, dahmer.number
    assert_equal 2, dahmer.match_players.count
    assert_equal ["Block"], dahmer.match_players.find_by(match: other).skills

    departed = Player.find_by(team: teams(:cackling_furies), name: "Departed")
    assert_nil departed.number
    assert_equal 1, departed.match_players.count

    assert_equal 3, Player.find_by(team: teams(:cackling_furies), name: "Newcomer").number
  end

  test "record_match_players! is a no-op without player data" do
    match = matches(:season_opener)
    assert_equal 0, match.record_match_players!({ "info" => { "type" => "main" } })
    assert_equal 0, match.record_match_players!(nil)
    assert_equal 0, match.match_players.count
  end

  test "upload_replay_json creates player versions" do
    match = matches(:season_opener)
    file = Tempfile.new(["replay", ".json"])
    file.write(new_format_json.to_json)
    file.rewind

    assert match.upload_replay_json(file)
    assert_equal 3, match.match_players.count
  ensure
    file&.close
    file&.unlink
  end

  test "upload_replay_jsons creates player versions for matching matches" do
    file = Tempfile.new(["replay", ".json"])
    file.write(new_format_json.merge("match_hash" => matches(:season_opener).match_hash).to_json)
    file.rewind

    result = Match.upload_replay_jsons([file])
    assert_equal({ uploaded: 1, skipped: 0 }, result)
    assert_equal 3, matches(:season_opener).reload.match_players.count
  ensure
    file&.close
    file&.unlink
  end
end
