require "test_helper"

class LeagueTest < ActiveSupport::TestCase
  setup do
    @league = League.create!(name: "Test League", slug: "test-league", platform: :pc)
  end

  def api_response(name:, id:)
    { "league" => { "name" => name, "id" => id } }
  end

  test "refresh_from_api updates league attributes" do
    data = api_response(name: "Updated League", id: "fdjklsajkl4324")
    original_league = CyanideApi::Client.instance_method(:league)
    original_competitions = CyanideApi::Client.instance_method(:competitions)
    CyanideApi::Client.define_method(:league) { |**| data }
    CyanideApi::Client.define_method(:competitions) { |**| { "competitions" => [] } }

    assert @league.refresh_from_api
    assert_equal "Updated League", @league.reload.name
    assert_equal "fdjklsajkl4324", @league.api_id
  ensure
    CyanideApi::Client.define_method(:league, original_league)
    CyanideApi::Client.define_method(:competitions, original_competitions)
  end

  test "refresh_from_api returns false on not found" do
    original = CyanideApi::Client.instance_method(:league)
    CyanideApi::Client.define_method(:league) { |**| raise CyanideApi::NotFoundError }

    refute @league.refresh_from_api
    assert_equal "League not found on API", @league.errors.full_messages.first
  ensure
    CyanideApi::Client.define_method(:league, original)
  end

  test "refresh_from_api returns false on API error" do
    original = CyanideApi::Client.instance_method(:league)
    CyanideApi::Client.define_method(:league) { |**| raise CyanideApi::Error, "Timeout" }

    refute @league.refresh_from_api
    assert_equal "Timeout", @league.errors.full_messages.first
  ensure
    CyanideApi::Client.define_method(:league, original)
  end

  test "refresh_from_api stores raw api_data" do
    data = api_response(name: "League", id: "fdjklsajkl4324")
    original_league = CyanideApi::Client.instance_method(:league)
    original_competitions = CyanideApi::Client.instance_method(:competitions)
    CyanideApi::Client.define_method(:league) { |**| data }
    CyanideApi::Client.define_method(:competitions) { |**| { "competitions" => [] } }

    @league.refresh_from_api
    assert_equal data, @league.reload.api_data
  ensure
    CyanideApi::Client.define_method(:league, original_league)
    CyanideApi::Client.define_method(:competitions, original_competitions)
  end

  test "refresh_from_api calls refresh_competitions and refresh_matches for active competitions" do
    comp_called = false
    match_called = false
    upcoming_called = false

    data = api_response(name: "Test", id: "1")
    original_league = CyanideApi::Client.instance_method(:league)
    CyanideApi::Client.define_method(:league) { |**| data }

    @league.define_singleton_method(:refresh_competitions) do
      comp_called = true
      competitions.create!(name: "Spy Comp", slug: "spy-comp", format: :round_robin, platform: :pc)
    end

    original_matches = Competition.instance_method(:refresh_matches)
    Competition.define_method(:refresh_matches) { match_called = true; true }
    original_upcoming = Competition.instance_method(:refresh_upcoming_matches)
    Competition.define_method(:refresh_upcoming_matches) { upcoming_called = true; true }
    original_active = Competition.instance_method(:active?)
    Competition.define_method(:active?) { true }

    @league.refresh_from_api

    assert comp_called
    assert match_called
    assert upcoming_called
  ensure
    CyanideApi::Client.define_method(:league, original_league)
    Competition.define_method(:refresh_matches, original_matches)
    Competition.define_method(:refresh_upcoming_matches, original_upcoming)
    Competition.define_method(:active?, original_active)
  end

  test "refresh_from_api refreshes competitions and matches" do
    data = api_response(name: "Test League", id: "fdjklsajkl4324")
    comps = [
      { "name" => "Season 15", "id" => 501, "format" => "RoundRobin" }
    ]
    api_matches = [
      { "uuid" => "m001", "teams" => [{ "idteamlisting" => "id-101", "teamname" => "Cackling Furies", "score" => 2 }, { "idteamlisting" => "id-102", "teamname" => "Razorback Raiders", "score" => 1 }] }
    ]
    Team.create!(name: "Cackling Furies", slug: "cackling-furies", api_id: "id-101")
    Team.create!(name: "Razorback Raiders", slug: "razorback-raiders", api_id: "id-102")

    original_league = CyanideApi::Client.instance_method(:league)
    original_competitions = CyanideApi::Client.instance_method(:competitions)
    original_matches = CyanideApi::Client.instance_method(:matches)
    original_contests = CyanideApi::Client.instance_method(:contests)
    original_ladder = CyanideApi::Client.instance_method(:ladder)
    CyanideApi::Client.define_method(:league) { |**| data }
    CyanideApi::Client.define_method(:competitions) { |**| { "competitions" => comps } }
    CyanideApi::Client.define_method(:matches) { |**| { "matches" => api_matches } }
    CyanideApi::Client.define_method(:contests) { |**| { "contests" => [{ "contest_id" => "c001", "status" => "scheduled", "round" => 1, "opponents" => [] }] } }
    CyanideApi::Client.define_method(:ladder) { |**| { "ranking" => [] } }

    # Make competition active so matches get refreshed
    original_active = Competition.instance_method(:active?)
    Competition.define_method(:active?) { true }

    assert @league.refresh_from_api
    assert_equal 1, @league.competitions.count
    competition = @league.competitions.first
    assert_equal "Season 15", competition.name
    assert_equal 1, competition.matches.count
    assert_equal "m001", competition.matches.first.api_id
  ensure
    CyanideApi::Client.define_method(:league, original_league)
    CyanideApi::Client.define_method(:competitions, original_competitions)
    CyanideApi::Client.define_method(:matches, original_matches)
    CyanideApi::Client.define_method(:contests, original_contests)
    CyanideApi::Client.define_method(:ladder, original_ladder)
    Competition.define_method(:active?, original_active)
  end

  test "refresh_from_api refreshes matches for all active competitions" do
    data = api_response(name: "Test League", id: "fdjklsajkl4324")
    comps = (1..5).map { |i| { "name" => "Season #{i}", "id" => 500 + i, "format" => "RoundRobin" } }
    original_league = CyanideApi::Client.instance_method(:league)
    original_competitions = CyanideApi::Client.instance_method(:competitions)
    CyanideApi::Client.define_method(:league) { |**| data }
    CyanideApi::Client.define_method(:competitions) { |**| { "competitions" => comps } }

    refreshed = []
    original_matches = Competition.instance_method(:refresh_matches)
    Competition.define_method(:refresh_matches) { refreshed << api_id; true }
    original_upcoming = Competition.instance_method(:refresh_upcoming_matches)
    Competition.define_method(:refresh_upcoming_matches) { true }
    # Make odd-numbered competitions active
    original_active = Competition.instance_method(:active?)
    Competition.define_method(:active?) { api_id.to_i.odd? }

    assert @league.refresh_from_api
    assert_equal 5, @league.competitions.count
    # Only odd-numbered competitions (501, 503, 505) should be active
    assert_equal %w[501 503 505], refreshed.sort
  ensure
    CyanideApi::Client.define_method(:league, original_league)
    CyanideApi::Client.define_method(:competitions, original_competitions)
    Competition.define_method(:refresh_matches, original_matches)
    Competition.define_method(:refresh_upcoming_matches, original_upcoming)
    Competition.define_method(:active?, original_active)
  end

  test "refresh_from_api marks finished competition correctly even without matches" do
    data = api_response(name: "Test League", id: "fdjklsajkl4324")
    comps = [
      { "name" => "Old Season", "id" => 501, "format" => "RoundRobin" },
      { "name" => "New Season", "id" => 502, "format" => "RoundRobin" }
    ]
    original_league = CyanideApi::Client.instance_method(:league)
    original_competitions = CyanideApi::Client.instance_method(:competitions)
    original_contests = CyanideApi::Client.instance_method(:contests)
    CyanideApi::Client.define_method(:league) { |**| data }
    CyanideApi::Client.define_method(:competitions) { |**| { "competitions" => comps } }
    # Old season: all contests played. New season: has upcoming contest.
    CyanideApi::Client.define_method(:contests) do |competition_id: nil, **|
      if competition_id.to_s == "501"
        { "contests" => [{ "contest_id" => "c1", "status" => "Validated", "round" => 1, "opponents" => [], "competition_id" => "501" }] }
      else
        { "contests" => [{ "contest_id" => "c2", "status" => "scheduled", "round" => 1, "opponents" => [], "competition_id" => "502" }] }
      end
    end
    original_ladder = CyanideApi::Client.instance_method(:ladder)
    CyanideApi::Client.define_method(:ladder) { |**| { "ranking" => [] } }

    assert @league.refresh_from_api
    old = @league.competitions.find_by(api_id: "501")
    new_comp = @league.competitions.find_by(api_id: "502")
    assert_equal "finished", old.status
    assert_equal "active", new_comp.status
  ensure
    CyanideApi::Client.define_method(:league, original_league)
    CyanideApi::Client.define_method(:competitions, original_competitions)
    CyanideApi::Client.define_method(:contests, original_contests)
    CyanideApi::Client.define_method(:ladder, original_ladder)
  end

  test "refresh_from_api skips polling finished competitions" do
    finished = @league.competitions.create!(name: "Old Season", slug: "old-season", api_id: "501", format: :round_robin, platform: :pc, status: :finished)
    @league.competitions.create!(name: "Current Season", slug: "current-season", api_id: "502", format: :round_robin, platform: :pc)

    data = api_response(name: "Test League", id: "fdjklsajkl4324")
    original_league = CyanideApi::Client.instance_method(:league)
    original_competitions = CyanideApi::Client.instance_method(:competitions)
    original_upcoming = Competition.instance_method(:refresh_upcoming_matches)
    CyanideApi::Client.define_method(:league) { |**| data }
    CyanideApi::Client.define_method(:competitions) { |**| { "competitions" => [] } }

    polled = []
    Competition.define_method(:refresh_upcoming_matches) { polled << api_id; false }

    assert @league.refresh_from_api
    assert_equal %w[502], polled
    assert_equal "finished", finished.reload.status
  ensure
    CyanideApi::Client.define_method(:league, original_league)
    CyanideApi::Client.define_method(:competitions, original_competitions)
    Competition.define_method(:refresh_upcoming_matches, original_upcoming)
  end

  test "refresh_competitions creates competitions from API" do
    comps = [
      { "name" => "Season 15", "id" => 501, "format" => "RoundRobin" },
      { "name" => "Playoffs", "id" => 502, "format" => "Knockout" }
    ]
    original = CyanideApi::Client.instance_method(:competitions)
    CyanideApi::Client.define_method(:competitions) { |**| { "competitions" => comps } }

    assert @league.refresh_competitions
    assert_equal 2, @league.competitions.count
    assert_equal "season-15", @league.competitions.find_by(api_id: "501").slug
    assert_equal "round_robin", @league.competitions.find_by(api_id: "501").format
    assert_equal "single_elimination", @league.competitions.find_by(api_id: "502").format
  ensure
    CyanideApi::Client.define_method(:competitions, original)
  end

  test "refresh_competitions updates existing competitions" do
    existing = @league.competitions.create!(name: "Old Name", slug: "old-name", api_id: "501", format: :round_robin, platform: :pc)
    comps = [{ "name" => "Season 15", "id" => 501, "format" => "RoundRobin" }]
    original = CyanideApi::Client.instance_method(:competitions)
    CyanideApi::Client.define_method(:competitions) { |**| { "competitions" => comps } }

    @league.refresh_competitions
    assert_equal "Season 15", existing.reload.name
    assert_equal 1, @league.competitions.count
  ensure
    CyanideApi::Client.define_method(:competitions, original)
  end

  test "refresh_competitions maps format Wissen to swiss" do
    comps = [{ "name" => "Swiss Cup", "id" => 601, "format" => "Wissen" }]
    original = CyanideApi::Client.instance_method(:competitions)
    CyanideApi::Client.define_method(:competitions) { |**| { "competitions" => comps } }

    @league.refresh_competitions
    assert_equal "swiss", @league.competitions.find_by(api_id: "601").format
  ensure
    CyanideApi::Client.define_method(:competitions, original)
  end

  test "refresh_competitions returns false on not found" do
    original = CyanideApi::Client.instance_method(:competitions)
    CyanideApi::Client.define_method(:competitions) { |**| raise CyanideApi::NotFoundError }

    refute @league.refresh_competitions
    assert_equal "Competitions not found on API", @league.errors.full_messages.first
  ensure
    CyanideApi::Client.define_method(:competitions, original)
  end

  test "refresh_competitions returns false on API error" do
    original = CyanideApi::Client.instance_method(:competitions)
    CyanideApi::Client.define_method(:competitions) { |**| raise CyanideApi::Error, "Timeout" }

    refute @league.refresh_competitions
    assert_equal "Timeout", @league.errors.full_messages.first
  ensure
    CyanideApi::Client.define_method(:competitions, original)
  end
end
