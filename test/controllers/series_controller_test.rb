require "test_helper"

class SeriesControllerTest < ActionDispatch::IntegrationTest
  test "predictor embeds teams and upcoming fixtures" do
    competitions(:rebell_season_15).update!(series: series(:rebbl_season_15))
    get predictor_series_path(series(:rebbl_season_15).slug)
    assert_response :success
    assert_select "h1", text: "Predictor: REBBL Season 15"
    assert_select "h2", text: "Upcoming Matches"
    assert_select "h5", text: "Round 3"
    assert_select "th", text: "Playoff"
    assert_select "th", text: "Σ", count: 0
    assert_select "input[type=range][data-predictor-target=slider]" do |sliders|
      assert sliders.all? { |s| (0..1).cover?(s[:value].to_f) }
    end
    assert_match(/Cackling Furies/, response.body)
    assert_match(/Razorback Raiders/, response.body)
    assert_match(/"round":3/, response.body)
  end

  test "predictor returns 404 for unknown series" do
    get predictor_series_path("does-not-exist")
    assert_response :not_found
  end

  test "predictor includes AI opponents as guaranteed wins" do
    competition = competitions(:rebell_season_15)
    competition.update!(series: series(:rebbl_season_15))
    competition.contests.create!(api_id: "cn-ai", round: 4, status: "Scheduled", home_team: teams(:cackling_furies))

    get predictor_series_path(series(:rebbl_season_15).slug)
    assert_response :success
    assert_select "h5", text: "Round 4"
    assert_select "input[type=range][value='0']"
    assert_match(/"ai":true/, response.body)
    assert_select ".fixture__name", text: "Cackling Furies"
    assert_select ".fixture__name", text: "CPU"
  end
end
