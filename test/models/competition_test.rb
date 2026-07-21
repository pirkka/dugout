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
    original_matches = CyanideApi::Client.instance_method(:matches)
    CyanideApi::Client.define_method(:matches) { |**| { "matches" => api_matches } }
    original_ladder = CyanideApi::Client.instance_method(:ladder)
    CyanideApi::Client.define_method(:ladder) { |**| { "ranking" => [] } }

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
    CyanideApi::Client.define_method(:matches, original_matches)
    CyanideApi::Client.define_method(:ladder, original_ladder)
  end

  test "refresh_matches updates existing match data" do
    home = Team.create!(name: "Cackling Furies", slug: "cackling-furies", api_id: "id-101")
    away = Team.create!(name: "Razorback Raiders", slug: "razorback-raiders", api_id: "id-102")
    existing = @competition.matches.create!(api_id: "abc-123", started: Time.zone.now, finished: Time.zone.now, round: 1)
    existing.match_teams.create!(team: home, score: 0, conceded: 0)

    api_matches = [
      { "uuid" => "abc-123", "started" => "2026-06-15 19:00:00", "finished" => "2026-06-15 20:00:00", "round" => 5, "teams" => [{ "idteamlisting" => "id-101", "teamname" => "Cackling Furies", "score" => 3 }, { "idteamlisting" => "id-102", "teamname" => "Razorback Raiders", "score" => 2 }] }
    ]
    original_matches = CyanideApi::Client.instance_method(:matches)
    CyanideApi::Client.define_method(:matches) { |**| { "matches" => api_matches } }
    original_ladder = CyanideApi::Client.instance_method(:ladder)
    CyanideApi::Client.define_method(:ladder) { |**| { "ranking" => [] } }

    @competition.refresh_matches
    assert_equal 1, @competition.matches.count
    assert_equal existing, @competition.matches.first
    assert_equal Time.zone.parse("2026-06-15 19:00:00"), existing.reload.started
    assert_equal Time.zone.parse("2026-06-15 20:00:00"), existing.finished
    assert_equal 5, existing.round
    assert_equal 3, existing.match_teams.find_by(team: home).score
  ensure
    CyanideApi::Client.define_method(:matches, original_matches)
    CyanideApi::Client.define_method(:ladder, original_ladder)
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

  test "remove_duplicate_matches keeps only newest match for each team pairing" do
    home = Team.create!(name: "Cackling Furies", slug: "cackling-furies", api_id: "id-101")
    away = Team.create!(name: "Razorback Raiders", slug: "razorback-raiders", api_id: "id-102")
    other = Team.create!(name: "Bad Bay Hackers", slug: "bad-bay-hackers", api_id: "id-103")

    oldest = @competition.matches.create!(api_id: "old", started: Time.zone.parse("2026-01-01 18:00:00"), round: 1)
    oldest.match_teams.create!(team: home, result: :win, score: 3, conceded: 1)
    oldest.match_teams.create!(team: away, result: :loss, score: 1, conceded: 3)

    middle = @competition.matches.create!(api_id: "mid", started: Time.zone.parse("2026-02-01 18:00:00"), round: 2)
    middle.match_teams.create!(team: home, result: :loss, score: 2, conceded: 4)
    middle.match_teams.create!(team: away, result: :win, score: 4, conceded: 2)

    newest = @competition.matches.create!(api_id: "new", started: Time.zone.parse("2026-03-01 18:00:00"), round: 3)
    newest.match_teams.create!(team: home, result: :draw, score: 2, conceded: 2)
    newest.match_teams.create!(team: away, result: :draw, score: 2, conceded: 2)

    solo = @competition.matches.create!(api_id: "solo", started: Time.zone.parse("2026-03-15 18:00:00"), round: 4)
    solo.match_teams.create!(team: home, result: :win, score: 5, conceded: 0)
    solo.match_teams.create!(team: other, result: :loss, score: 0, conceded: 5)

    @competition.remove_duplicate_matches

    remaining = @competition.matches.reload
    assert_equal 2, remaining.count
    assert_includes remaining, newest
    assert_includes remaining, solo
  end

  test "remove_duplicate_matches handles nil started" do
    home = Team.create!(name: "Cackling Furies", slug: "cackling-furies", api_id: "id-101")
    away = Team.create!(name: "Razorback Raiders", slug: "razorback-raiders", api_id: "id-102")

    no_date = @competition.matches.create!(api_id: "no-date", started: nil, round: 1)
    no_date.match_teams.create!(team: home, score: 1, conceded: 1)
    no_date.match_teams.create!(team: away, score: 1, conceded: 1)

    with_date = @competition.matches.create!(api_id: "with-date", started: Time.zone.parse("2026-06-01 18:00:00"), round: 2)
    with_date.match_teams.create!(team: home, score: 2, conceded: 0)
    with_date.match_teams.create!(team: away, score: 0, conceded: 2)

    @competition.remove_duplicate_matches

    assert_equal 1, @competition.matches.reload.count
    assert_includes @competition.matches, with_date
  end

  test "remove_duplicate_matches leaves single pairings alone" do
    home = Team.create!(name: "Cackling Furies", slug: "cackling-furies", api_id: "id-101")
    away = Team.create!(name: "Razorback Raiders", slug: "razorback-raiders", api_id: "id-102")

    match = @competition.matches.create!(api_id: "only", started: Time.zone.parse("2026-06-01 18:00:00"), round: 1)
    match.match_teams.create!(team: home, score: 2, conceded: 1)
    match.match_teams.create!(team: away, score: 1, conceded: 2)

    @competition.remove_duplicate_matches

    assert_equal 1, @competition.matches.reload.count
  end

  test "refresh_standings updates competition_teams from ladder data" do
    team1 = Team.create!(name: "Cackling Furies", slug: "cackling-furies", api_id: "id-101")
    team2 = Team.create!(name: "Razorback Raiders", slug: "razorback-raiders", api_id: "id-102")
    ct1 = @competition.competition_teams.create!(team: team1)
    ct2 = @competition.competition_teams.create!(team: team2)

    api_response = {
      "ranking" => [
        { "team" => { "id" => "id-101", "name" => "Cackling Furies", "rank" => 1, "w/d/l" => "6/1/1" }, "score" => 1850 },
        { "team" => { "id" => "id-102", "name" => "Razorback Raiders", "rank" => 2, "w/d/l" => "4/2/3" }, "score" => 1720 }
      ]
    }
    original = CyanideApi::Client.instance_method(:ladder)
    CyanideApi::Client.define_method(:ladder) { |**| api_response }

    assert @competition.refresh_standings

    ct1.reload
    assert_equal 1, ct1.position
    assert_equal 8, ct1.matches
    assert_equal 6, ct1.wins
    assert_equal 1, ct1.draws
    assert_equal 1, ct1.losses
    assert_equal 19, ct1.points
    assert_equal 1850, ct1.score

    ct2.reload
    assert_equal 2, ct2.position
    assert_equal 9, ct2.matches
    assert_equal 4, ct2.wins
    assert_equal 2, ct2.draws
    assert_equal 3, ct2.losses
    assert_equal 14, ct2.points
    assert_equal 1720, ct2.score
  ensure
    CyanideApi::Client.define_method(:ladder, original)
  end

  test "refresh_standings skips teams not in competition" do
    team = Team.create!(name: "Cackling Furies", slug: "cackling-furies", api_id: "id-101")
    @competition.competition_teams.create!(team: team)

    api_response = {
      "ranking" => [
        { "team" => { "id" => "id-101", "name" => "Cackling Furies", "rank" => 1, "w/d/l" => "3/0/0" } },
        { "team" => { "id" => "id-999", "name" => "Unknown Team", "rank" => 2, "w/d/l" => "2/0/0" } }
      ]
    }
    original = CyanideApi::Client.instance_method(:ladder)
    CyanideApi::Client.define_method(:ladder) { |**| api_response }

    @competition.refresh_standings
    assert_equal 1, @competition.competition_teams.count
    assert_equal 3, @competition.competition_teams.first.reload.matches
  ensure
    CyanideApi::Client.define_method(:ladder, original)
  end

  test "refresh_standings returns false on not found" do
    original = CyanideApi::Client.instance_method(:ladder)
    CyanideApi::Client.define_method(:ladder) { |**| raise CyanideApi::NotFoundError }

    refute @competition.refresh_standings
    assert_equal "Ladder not found on API", @competition.errors.full_messages.first
  ensure
    CyanideApi::Client.define_method(:ladder, original)
  end

  test "refresh_standings returns false on API error" do
    original = CyanideApi::Client.instance_method(:ladder)
    CyanideApi::Client.define_method(:ladder) { |**| raise CyanideApi::Error, "Timeout" }

    refute @competition.refresh_standings
    assert_equal "Timeout", @competition.errors.full_messages.first
  ensure
    CyanideApi::Client.define_method(:ladder, original)
  end
end
