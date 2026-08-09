require "test_helper"

class MatchTest < ActiveSupport::TestCase
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
end
