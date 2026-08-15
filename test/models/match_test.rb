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

  test "record_player_versions! creates versions from new format json" do
    match = matches(:season_opener)
    count = match.record_player_versions!(new_format_json)

    assert_equal 3, count
    assert_equal 3, match.player_versions.count

    home = match.player_versions.find_by(name: "Ilona 'The Queen'")
    assert_equal teams(:cackling_furies), home.player.team
    assert_equal 1, home.number
    assert_equal "Black Orc", home.kind
    assert_equal ["Guard"], home.skills
    assert_equal "normal", home.status
    assert_equal 1650, home.team_value
    assert_equal "new", home.format

    away = match.player_versions.find_by(name: "Ratty")
    assert_equal teams(:razorback_raiders), away.player.team
    assert_equal 1, away.number
  end

  test "record_player_versions! creates versions from old format json with away offset" do
    match = matches(:season_opener)
    count = match.record_player_versions!(old_format_json)

    assert_equal 2, count

    home = match.player_versions.find_by(name: "Ilona 'The Queen'")
    assert_equal teams(:cackling_furies), home.player.team
    assert_equal 1, home.number
    assert_equal 14, home.player_type
    assert_equal "old", home.format

    away = match.player_versions.find_by(name: "Ratty")
    assert_equal teams(:razorback_raiders), away.player.team
    assert_equal 7, away.number
  end

  test "record_player_versions! replaces versions on reprocess" do
    match = matches(:season_opener)
    match.record_player_versions!(new_format_json)
    match.record_player_versions!(new_format_json)

    assert_equal 3, match.player_versions.count
    assert_equal 3, match.reload.player_versions.count
  end

  test "record_player_versions! keeps player identity across matches" do
    match = matches(:season_opener)
    other = matches(:final_showdown)
    MatchTeam.create!(match: other, team: teams(:cackling_furies), home: true)
    MatchTeam.create!(match: other, team: teams(:razorback_raiders), home: false)

    match.record_player_versions!(new_format_json)
    other.record_player_versions!(new_format_json)

    ilona = Player.find_by(team: teams(:cackling_furies), name: "Ilona 'The Queen'")
    assert_equal 2, ilona.player_versions.count
    assert_includes ilona.player_versions.pluck(:match_id), other.id
  end

  test "record_player_versions! captures the severest injury_type from highlights" do
    match = matches(:season_opener)
    json = new_format_json
    json["highlights"] = [
      { "event" => "injury_caused", "injured_player_id" => "2", "injury_type" => "knocked_out" },
      { "event" => "injury_caused", "injured_player_id" => "2", "injury_type" => "mng" },
      { "event" => "touch_down", "player_id" => "1" }
    ]

    match.record_player_versions!(json)

    injured = match.player_versions.find_by(name: "Trinity 'The Rookie'")
    assert_equal Player::MNG, injured.injury_type
    assert_nil match.player_versions.find_by(name: "Ilona 'The Queen'").injury_type
  end

  test "record_player_versions! marks dead players with the highest priority" do
    match = matches(:season_opener)
    json = new_format_json
    json["highlights"] = [
      { "event" => "injury_caused", "injured_player_id" => "2", "injury_type" => "dead" },
      { "event" => "injury_caused", "injured_player_id" => "2", "injury_type" => "mng" }
    ]

    match.record_player_versions!(json)

    assert_equal Player::DEAD, match.player_versions.find_by(name: "Trinity 'The Rookie'").injury_type
  end

  test "record_player_versions! handles renumbering across matches" do
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

    match.record_player_versions!(first)
    other.record_player_versions!(second)

    ilona = Player.find_by(team: teams(:cackling_furies), name: "Ilona 'The Queen'")
    assert_equal 2, ilona.player_versions.count

    dahmer = Player.find_by(team: teams(:cackling_furies), name: "Jeffrey Dahmer")
    assert_equal 2, dahmer.number
    assert_equal 2, dahmer.player_versions.count
    assert_equal ["Block"], dahmer.player_versions.find_by(match: other).skills

    departed = Player.find_by(team: teams(:cackling_furies), name: "Departed")
    assert_nil departed.number
    assert_equal 1, departed.player_versions.count

    assert_equal 3, Player.find_by(team: teams(:cackling_furies), name: "Newcomer").number
  end

  test "record_player_versions! is a no-op without player data" do
    match = matches(:season_opener)
    assert_equal 0, match.record_player_versions!({ "info" => { "type" => "main" } })
    assert_equal 0, match.record_player_versions!(nil)
    assert_equal 0, match.player_versions.count
  end

  test "upload_replay_json creates player versions" do
    match = matches(:season_opener)
    file = Tempfile.new(["replay", ".json"])
    file.write(new_format_json.to_json)
    file.rewind

    assert match.upload_replay_json(file)
    assert_equal 3, match.player_versions.count
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
    assert_equal 3, matches(:season_opener).reload.player_versions.count
  ensure
    file&.close
    file&.unlink
  end
end
