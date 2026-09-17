require "test_helper"

class PredictorBaselineTest < ActiveSupport::TestCase
  def baseline(team_records: {}, h2h_records: {})
    PredictorBaseline.new(team_records: team_records, h2h_records: h2h_records)
  end

  test "stronger home team starts favored" do
    recs = {
      1 => { matches: 20, wins: 18, draws: 1 },
      2 => { matches: 20, wins: 2, draws: 1 }
    }
    assert_operator baseline(team_records: recs).value(1, 2), :>, 0.5
  end

  test "stronger away team starts favored for them" do
    recs = {
      1 => { matches: 20, wins: 2, draws: 1 },
      2 => { matches: 20, wins: 18, draws: 1 }
    }
    assert_operator baseline(team_records: recs).value(1, 2), :<, 0.5
  end

  test "even teams start at the midpoint" do
    recs = {
      1 => { matches: 10, wins: 5, draws: 1 },
      2 => { matches: 10, wins: 5, draws: 1 }
    }
    assert_equal 0.5, baseline(team_records: recs).value(1, 2)
  end

  test "no data falls back to midpoint" do
    assert_equal 0.5, baseline.value(1, 2)
  end

  test "head-to-head gives extra weight to past encounters" do
    recs = { 1 => { matches: 10, wins: 5, draws: 1 }, 2 => { matches: 10, wins: 5, draws: 1 } }
    h2h = { [ 1, 2 ].minmax => { matches: 4, wins_by: { 1 => 4, 2 => 0 }, draws: 0 } }
    assert_operator baseline(team_records: recs, h2h_records: h2h).value(1, 2), :>, 0.5
  end

  test "values stay clamped and rounded to slider step" do
    recs = {
      1 => { matches: 100, wins: 100, draws: 0 },
      2 => { matches: 100, wins: 0, draws: 0 }
    }
    v = baseline(team_records: recs).value(1, 2)
    assert_equal 0.95, v
    assert_equal v, v.round(2)
  end
end
