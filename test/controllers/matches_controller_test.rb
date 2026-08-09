require "test_helper"

class MatchesControllerTest < ActionDispatch::IntegrationTest
  test "replays page renders" do
    get replays_path
    assert_response :success
    assert_select "input[type=file][name='replay_jsons[]'][multiple]"
  end

  test "upload_replay_batch redirects with summary notice" do
    match = matches(:season_opener)
    file = Rack::Test::UploadedFile.new("test/fixtures/replay.json", "application/json")
    post upload_replay_batch_matches_path, params: { replay_jsons: [file] }
    assert_redirected_to replays_path
    assert_equal "Uploaded 1 replay(s), skipped 0", flash[:notice]
    assert_equal "main", match.reload.replay_json.dig("info", "type")
  end

  test "upload_replay_batch uploads multiple files" do
    opener = matches(:season_opener)
    showdown = matches(:final_showdown)
    file1 = Rack::Test::UploadedFile.new("test/fixtures/replay.json", "application/json")
    file2 = Rack::Test::UploadedFile.new("test/fixtures/replay_second.json", "application/json")
    post upload_replay_batch_matches_path, params: { replay_jsons: [file1, file2] }
    assert_redirected_to replays_path
    assert_equal "Uploaded 2 replay(s), skipped 0", flash[:notice]
    assert_equal "main", opener.reload.replay_json.dig("info", "type")
    assert_equal "main", showdown.reload.replay_json.dig("info", "type")
  end

  test "upload_replay_batch reports skipped files" do
    post upload_replay_batch_matches_path, params: { replay_jsons: [] }
    assert_redirected_to replays_path
    assert_equal "Uploaded 0 replay(s), skipped 0", flash[:notice]
  end
end
