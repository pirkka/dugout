require "test_helper"

class CompetitionTest < ActiveSupport::TestCase
  setup do
    @league = leagues(:rebell)
    @competition = @league.competitions.create!(name: "Test Cup", slug: "test-cup", format: :round_robin, platform: :pc)
  end

  test "refresh_teams creates teams and join records" do
    api_teams = [
      { "team" => "Cackling Furies", "id" => 101, "value" => 1100, "cash" => 200_000, "rerolls" => 3, "apothecary" => 1, "assistant_coaches" => 0, "cheerleaders" => 0, "popularity" => 1, "logo" => nil, "coach_id" => 1, "race" => "human" },
      { "team" => "Razorback Raiders", "id" => 102, "value" => 1250, "cash" => 150_000, "rerolls" => 2, "apothecary" => 0, "assistant_coaches" => 1, "cheerleaders" => 1, "popularity" => 2, "logo" => nil, "coach_id" => 2, "race" => "dwarf" }
    ]
    original = CyanideApi::Client.instance_method(:teams)
    CyanideApi::Client.define_method(:teams) { |**| { "teams" => api_teams } }

    assert @competition.refresh_teams
    assert_equal 2, @competition.teams.count
    assert_equal "Cackling Furies", @competition.teams.find_by(api_id: "101").name
    assert_equal 1100, @competition.teams.find_by(api_id: "101").value
  ensure
    CyanideApi::Client.define_method(:teams, original)
  end

  test "refresh_teams reuses existing team records" do
    existing = Team.create!(name: "Cackling Furies", slug: "cackling-furies", api_id: "101")
    api_teams = [{ "team" => "Cackling Furies", "id" => 101, "value" => 1200, "cash" => 0, "rerolls" => 0, "apothecary" => 0, "assistant_coaches" => 0, "cheerleaders" => 0, "popularity" => 0, "logo" => nil, "coach_id" => nil, "race" => "human" }]
    original = CyanideApi::Client.instance_method(:teams)
    CyanideApi::Client.define_method(:teams) { |**| { "teams" => api_teams } }

    @competition.refresh_teams
    assert_equal 1, @competition.teams.count
    assert_equal existing, @competition.teams.first
    assert_equal 1200, existing.reload.value
  ensure
    CyanideApi::Client.define_method(:teams, original)
  end

  test "refresh_teams returns false on not found" do
    original = CyanideApi::Client.instance_method(:teams)
    CyanideApi::Client.define_method(:teams) { |**| raise CyanideApi::NotFoundError }

    refute @competition.refresh_teams
    assert_equal "Teams not found on API", @competition.errors.full_messages.first
  ensure
    CyanideApi::Client.define_method(:teams, original)
  end

  test "refresh_teams returns false on API error" do
    original = CyanideApi::Client.instance_method(:teams)
    CyanideApi::Client.define_method(:teams) { |**| raise CyanideApi::Error, "Timeout" }

    refute @competition.refresh_teams
    assert_equal "Timeout", @competition.errors.full_messages.first
  ensure
    CyanideApi::Client.define_method(:teams, original)
  end

  test "refresh_matches creates matches and match_teams" do
    home = Team.create!(name: "Cackling Furies", slug: "cackling-furies", api_id: "id-101")
    away = Team.create!(name: "Razorback Raiders", slug: "razorback-raiders", api_id: "id-102")
    api_matches = [
      { "uuid" => "abc-123", "started" => "2026-06-01 19:00:00", "finished" => "2026-06-01 20:30:00", "round" => 3, "teams" => [{ "idteamlisting" => "id-101", "teamname" => "Cackling Furies", "score" => 2 }, { "idteamlisting" => "id-102", "teamname" => "Razorback Raiders", "score" => 1 }] }
    ]
    original = CyanideApi::Client.instance_method(:matches)
    CyanideApi::Client.define_method(:matches) { |**| { "matches" => api_matches } }

    assert @competition.refresh_matches
    assert_equal 1, @competition.matches.count
    match = @competition.matches.first
    assert_equal "abc-123", match.api_id
    assert_equal Time.zone.parse("2026-06-01 19:00:00"), match.started
    assert_equal Time.zone.parse("2026-06-01 20:30:00"), match.finished
    assert_equal 3, match.round
    assert_equal 2, match.teams.count
    assert_includes match.teams, home
    assert_includes match.teams, away

    home_mt = match.match_teams.find_by(team: home)
    assert_equal 2, home_mt.score
    assert_equal 1, home_mt.conceded
    assert_equal({ "idteamlisting" => "id-101", "teamname" => "Cackling Furies", "score" => 2 }, home_mt.api_data)
  ensure
    CyanideApi::Client.define_method(:matches, original)
  end

  test "refresh_matches updates existing match data" do
    home = Team.create!(name: "Cackling Furies", slug: "cackling-furies", api_id: "id-101")
    away = Team.create!(name: "Razorback Raiders", slug: "razorback-raiders", api_id: "id-102")
    existing = @competition.matches.create!(api_id: "abc-123", started: Time.zone.now, finished: Time.zone.now, round: 1)
    existing.match_teams.create!(team: home, score: 0, conceded: 0)

    api_matches = [
      { "uuid" => "abc-123", "started" => "2026-06-15 19:00:00", "finished" => "2026-06-15 20:00:00", "round" => 5, "teams" => [{ "idteamlisting" => "id-101", "teamname" => "Cackling Furies", "score" => 3 }, { "idteamlisting" => "id-102", "teamname" => "Razorback Raiders", "score" => 2 }] }
    ]
    original = CyanideApi::Client.instance_method(:matches)
    CyanideApi::Client.define_method(:matches) { |**| { "matches" => api_matches } }

    @competition.refresh_matches
    assert_equal 1, @competition.matches.count
    assert_equal existing, @competition.matches.first
    assert_equal Time.zone.parse("2026-06-15 19:00:00"), existing.reload.started
    assert_equal Time.zone.parse("2026-06-15 20:00:00"), existing.finished
    assert_equal 5, existing.round
    assert_equal 3, existing.match_teams.find_by(team: home).score
  ensure
    CyanideApi::Client.define_method(:matches, original)
  end

  test "refresh_matches returns false on not found" do
    original = CyanideApi::Client.instance_method(:matches)
    CyanideApi::Client.define_method(:matches) { |**| raise CyanideApi::NotFoundError }

    refute @competition.refresh_matches
    assert_equal "Matches not found on API", @competition.errors.full_messages.first
  ensure
    CyanideApi::Client.define_method(:matches, original)
  end

  test "refresh_matches returns false on API error" do
    original = CyanideApi::Client.instance_method(:matches)
    CyanideApi::Client.define_method(:matches) { |**| raise CyanideApi::Error, "Timeout" }

    refute @competition.refresh_matches
    assert_equal "Timeout", @competition.errors.full_messages.first
  ensure
    CyanideApi::Client.define_method(:matches, original)
  end
end
