require "test_helper"

class CompetitionTest < ActiveSupport::TestCase
  setup do
    @league = leagues(:rebell)
    @competition = @league.competitions.create!(name: "Test Cup", slug: "test-cup", format: :round_robin, platform: :pc)
  end

  test "refresh_teams creates teams and join records" do
    api_teams = [
      { "team" => "Cackling Furies", "id" => 101, "rerolls" => 3, "apothecary" => 1, "coach_assistants" => 0, "cheerleaders" => 0, "dedicated_fans" => 1, "logo" => nil, "coach_id" => 1, "race" => "human" },
      { "team" => "Razorback Raiders", "id" => 102, "rerolls" => 2, "apothecary" => 0, "coach_assistants" => 1, "cheerleaders" => 1, "dedicated_fans" => 2, "logo" => nil, "coach_id" => 2, "race" => "dwarf" }
    ]
    original = CyanideApi::Client.instance_method(:teams)
    CyanideApi::Client.define_method(:teams) { |**| { "teams" => api_teams } }

    assert @competition.refresh_teams
    assert_equal 2, @competition.teams.count
    team = @competition.teams.find_by(api_id: "101")
    assert_equal "Cackling Furies", team.name
    assert_nil team.value
    assert_equal 1, team.popularity
  ensure
    CyanideApi::Client.define_method(:teams, original)
  end

  test "refresh_teams preserves values not included in the list response" do
    existing = Team.create!(name: "Cackling Furies", slug: "cackling-furies", api_id: "101", value: 1200, cash: 50_000)
    api_teams = [{ "team" => "Cackling Furies", "id" => 101, "rerolls" => 0, "apothecary" => 0, "coach_assistants" => 0, "cheerleaders" => 0, "dedicated_fans" => 4, "logo" => nil, "coach_id" => nil, "race" => "human" }]
    original = CyanideApi::Client.instance_method(:teams)
    CyanideApi::Client.define_method(:teams) { |**| { "teams" => api_teams } }

    @competition.refresh_teams
    assert_equal 1, @competition.teams.count
    assert_equal existing, @competition.teams.first
    existing.reload
    assert_equal 1200, existing.value
    assert_equal 50_000, existing.cash
    assert_equal 4, existing.popularity
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
    original_contests = CyanideApi::Client.instance_method(:contests)
    CyanideApi::Client.define_method(:contests) { |**| { "contests" => [] } }
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
    CyanideApi::Client.define_method(:contests, original_contests)
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
    original_contests = CyanideApi::Client.instance_method(:contests)
    CyanideApi::Client.define_method(:contests) { |**| { "contests" => [] } }
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
    CyanideApi::Client.define_method(:contests, original_contests)
    CyanideApi::Client.define_method(:ladder, original_ladder)
  end

  test "refresh_matches derives round from contests for bb3" do
    league = League.create!(name: "BB3 League", slug: "bb3-league", platform: :pc, game_version: :bb3)
    comp = league.competitions.create!(name: "BB3 Cup", slug: "bb3-cup", format: :round_robin, platform: :pc)
    home = Team.create!(name: "Cackling Furies", slug: "cackling-furies", api_id: "id-101")
    away = Team.create!(name: "Razorback Raiders", slug: "razorback-raiders", api_id: "id-102")
    api_matches = [
      { "uuid" => "abc-123", "started" => "2026-06-01 19:00:00", "finished" => "2026-06-01 20:30:00", "round" => nil, "teams" => [{ "idteamlisting" => "id-101", "teamname" => "Cackling Furies", "score" => 2 }, { "idteamlisting" => "id-102", "teamname" => "Razorback Raiders", "score" => 1 }] }
    ]
    original_matches = CyanideApi::Client.instance_method(:matches)
    CyanideApi::Client.define_method(:matches) { |**| { "matches" => api_matches } }
    original_contests = CyanideApi::Client.instance_method(:contests)
    CyanideApi::Client.define_method(:contests) { |**| { "contests" => [{ "game_id" => "abc-123", "round" => 4 }] } }
    original_ladder = CyanideApi::Client.instance_method(:ladder)
    CyanideApi::Client.define_method(:ladder) { |**| { "ranking" => [] } }

    assert comp.refresh_matches
    assert_equal 4, comp.matches.first.round
  ensure
    CyanideApi::Client.define_method(:matches, original_matches)
    CyanideApi::Client.define_method(:contests, original_contests)
    CyanideApi::Client.define_method(:ladder, original_ladder)
  end

  test "refresh_matches ignores round 0 from contests for bb3" do
    league = League.create!(name: "BB3 League", slug: "bb3-league", platform: :pc, game_version: :bb3)
    comp = league.competitions.create!(name: "BB3 Cup", slug: "bb3-cup", format: :round_robin, platform: :pc)
    home = Team.create!(name: "Cackling Furies", slug: "cackling-furies", api_id: "id-101")
    away = Team.create!(name: "Razorback Raiders", slug: "razorback-raiders", api_id: "id-102")
    api_matches = [
      { "uuid" => "abc-123", "started" => "2026-06-01 19:00:00", "finished" => "2026-06-01 20:30:00", "round" => nil, "teams" => [{ "idteamlisting" => "id-101", "teamname" => "Cackling Furies", "score" => 2 }, { "idteamlisting" => "id-102", "teamname" => "Razorback Raiders", "score" => 1 }] }
    ]
    original_matches = CyanideApi::Client.instance_method(:matches)
    CyanideApi::Client.define_method(:matches) { |**| { "matches" => api_matches } }
    original_contests = CyanideApi::Client.instance_method(:contests)
    CyanideApi::Client.define_method(:contests) { |**| { "contests" => [{ "game_id" => "abc-123", "round" => 0 }] } }
    original_ladder = CyanideApi::Client.instance_method(:ladder)
    CyanideApi::Client.define_method(:ladder) { |**| { "ranking" => [] } }

    assert comp.refresh_matches
    assert_nil comp.matches.first.round
  ensure
    CyanideApi::Client.define_method(:matches, original_matches)
    CyanideApi::Client.define_method(:contests, original_contests)
    CyanideApi::Client.define_method(:ladder, original_ladder)
  end

  test "refresh_matches does not call contests for bb2" do
    league = League.create!(name: "BB2 League", slug: "bb2-league", platform: :pc, game_version: :bb2)
    comp = league.competitions.create!(name: "BB2 Cup", slug: "bb2-cup", format: :round_robin, platform: :pc)
    home = Team.create!(name: "Cackling Furies", slug: "cackling-furies", api_id: "id-101")
    away = Team.create!(name: "Razorback Raiders", slug: "razorback-raiders", api_id: "id-102")
    api_matches = [
      { "uuid" => "abc-123", "started" => "2026-06-01 19:00:00", "finished" => "2026-06-01 20:30:00", "round" => 3, "teams" => [{ "idteamlisting" => "id-101", "teamname" => "Cackling Furies", "score" => 2 }, { "idteamlisting" => "id-102", "teamname" => "Razorback Raiders", "score" => 1 }] }
    ]
    contests_called = false
    original_matches = CyanideApi::Client.instance_method(:matches)
    CyanideApi::Client.define_method(:matches) { |**| { "matches" => api_matches } }
    original_contests = CyanideApi::Client.instance_method(:contests)
    CyanideApi::Client.define_method(:contests) { |**| contests_called = true; { "contests" => [] } }
    original_ladder = CyanideApi::Client.instance_method(:ladder)
    CyanideApi::Client.define_method(:ladder) { |**| { "ranking" => [] } }

    assert comp.refresh_matches
    assert_equal 3, comp.matches.first.round
    refute contests_called
  ensure
    CyanideApi::Client.define_method(:matches, original_matches)
    CyanideApi::Client.define_method(:contests, original_contests)
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

  test "refresh_upcoming_matches creates contests and skips validated" do
    api_contests = [
      { "contest_id" => "cn-001", "match_id" => "mc-001", "round" => 3, "contest_status" => "Scheduled", "match_date" => "2026-08-20 19:00:00", "opponents" => [] },
      { "contest_id" => "cn-002", "match_id" => "mc-002", "round" => 3, "contest_status" => "Validated", "match_date" => "2026-08-10 19:00:00", "opponents" => [] }
    ]
    original = CyanideApi::Client.instance_method(:contests)
    CyanideApi::Client.define_method(:contests) { |**| { "contests" => api_contests } }

    assert @competition.refresh_upcoming_matches
    assert_equal 1, @competition.contests.count
    contest = @competition.contests.first
    assert_equal "cn-001", contest.api_id
    assert_equal "mc-001", contest.match_id
    assert_equal 3, contest.round
    assert_equal "Scheduled", contest.status
    assert_equal Time.zone.parse("2026-08-20 19:00:00"), contest.match_date
  ensure
    CyanideApi::Client.define_method(:contests, original)
  end

  test "refresh_upcoming_matches links home and away teams" do
    home = Team.create!(name: "Cackling Furies", slug: "cackling-furies", api_id: "id-101")
    away = Team.create!(name: "Razorback Raiders", slug: "razorback-raiders", api_id: "id-102")
    api_contests = [
      { "contest_id" => "cn-001", "match_id" => "mc-001", "round" => 1, "contest_status" => "Scheduled", "match_date" => nil, "opponents" => [{ "team" => { "id" => "id-101" } }, { "team" => { "id" => "id-102" } }] }
    ]
    original = CyanideApi::Client.instance_method(:contests)
    CyanideApi::Client.define_method(:contests) { |**| { "contests" => api_contests } }

    @competition.refresh_upcoming_matches
    contest = @competition.contests.first
    assert_equal home, contest.home_team
    assert_equal away, contest.away_team
  ensure
    CyanideApi::Client.define_method(:contests, original)
  end

  test "refresh_upcoming_matches leaves team nil when opponent not found" do
    api_contests = [
      { "contest_id" => "cn-001", "match_id" => "mc-001", "round" => 1, "contest_status" => "Scheduled", "match_date" => nil, "opponents" => [{ "team" => { "id" => "id-999" } }, { "team" => { "idteamlisting" => "id-888" } }] }
    ]
    original = CyanideApi::Client.instance_method(:contests)
    CyanideApi::Client.define_method(:contests) { |**| { "contests" => api_contests } }

    @competition.refresh_upcoming_matches
    contest = @competition.contests.first
    assert_nil contest.home_team
    assert_nil contest.away_team
  ensure
    CyanideApi::Client.define_method(:contests, original)
  end

  test "refresh_upcoming_matches updates existing contest" do
    @competition.contests.create!(api_id: "cn-001", match_id: "mc-000", round: 1, status: "Scheduled")
    api_contests = [
      { "contest_id" => "cn-001", "match_id" => "mc-001", "round" => 4, "contest_status" => "InProgress", "match_date" => "2026-08-22 19:00:00", "opponents" => [] }
    ]
    original = CyanideApi::Client.instance_method(:contests)
    CyanideApi::Client.define_method(:contests) { |**| { "contests" => api_contests } }

    @competition.refresh_upcoming_matches
    assert_equal 1, @competition.contests.count
    contest = @competition.contests.first
    assert_equal "mc-001", contest.match_id
    assert_equal 4, contest.round
    assert_equal "InProgress", contest.status
    assert_equal Time.zone.parse("2026-08-22 19:00:00"), contest.match_date
  ensure
    CyanideApi::Client.define_method(:contests, original)
  end

  test "refresh_upcoming_matches removes contests no longer upcoming" do
    stale = @competition.contests.create!(api_id: "cn-stale", match_id: "mc-stale", round: 1, status: "Scheduled")
    api_contests = [
      { "contest_id" => "cn-001", "match_id" => "mc-001", "round" => 1, "contest_status" => "Scheduled", "match_date" => nil, "opponents" => [] }
    ]
    original = CyanideApi::Client.instance_method(:contests)
    CyanideApi::Client.define_method(:contests) { |**| { "contests" => api_contests } }

    @competition.refresh_upcoming_matches
    assert_equal 1, @competition.contests.count
    refute_includes @competition.contests, stale
    assert_equal "cn-001", @competition.contests.first.api_id
  ensure
    CyanideApi::Client.define_method(:contests, original)
  end

  test "refresh_upcoming_matches does not wipe contests on empty response" do
    contest = @competition.contests.create!(api_id: "cn-001", match_id: "mc-001", round: 1, status: "Scheduled")
    original = CyanideApi::Client.instance_method(:contests)
    CyanideApi::Client.define_method(:contests) { |**| { "contests" => [] } }

    @competition.refresh_upcoming_matches
    assert_equal 1, @competition.contests.count
    assert_includes @competition.contests, contest
  ensure
    CyanideApi::Client.define_method(:contests, original)
  end

  test "refresh_upcoming_matches returns false on not found" do
    original = CyanideApi::Client.instance_method(:contests)
    CyanideApi::Client.define_method(:contests) { |**| raise CyanideApi::NotFoundError }

    refute @competition.refresh_upcoming_matches
    assert_equal "Upcoming matches not found on API", @competition.errors.full_messages.first
  ensure
    CyanideApi::Client.define_method(:contests, original)
  end

  test "refresh_upcoming_matches returns false on API error" do
    original = CyanideApi::Client.instance_method(:contests)
    CyanideApi::Client.define_method(:contests) { |**| raise CyanideApi::Error, "Timeout" }

    refute @competition.refresh_upcoming_matches
    assert_equal "Timeout", @competition.errors.full_messages.first
  ensure
    CyanideApi::Client.define_method(:contests, original)
  end

  test "refresh_upcoming_matches creates contests from bb2 upcoming_matches" do
    league = League.create!(name: "BB2 League", slug: "bb2-league", platform: :pc, game_version: :bb2)
    comp = league.competitions.create!(name: "Lihamylly, kierros 3", slug: "lihamylly-kierros-3", api_id: "396473", format: :round_robin, platform: :pc)
    home = Team.create!(name: "Kalevala Kaaoksessa", slug: "kalevala-kaaoksessa", api_id: "6436080")
    away = Team.create!(name: "Korkeampi Tietoisuus", slug: "korkeampi-tietoisuus", api_id: "6435681")
    api_contests = [
      { "contest_id" => 2726554, "competition_id" => 396473, "round" => 2, "status" => "scheduled", "match_date" => nil, "opponents" => [{ "team" => { "id" => 6436080 } }, { "team" => { "id" => 6435681 } }] },
      { "contest_id" => 2726555, "competition_id" => 396473, "round" => 2, "status" => "played", "opponents" => [] }
    ]
    original = CyanideApi::Client.instance_method(:contests)
    CyanideApi::Client.define_method(:contests) { |**| { "upcoming_matches" => api_contests } }

    assert comp.refresh_upcoming_matches
    assert_equal 1, comp.contests.count
    contest = comp.contests.first
    assert_equal "2726554", contest.api_id
    assert_equal 2, contest.round
    assert_equal "scheduled", contest.status
    assert_equal home, contest.home_team
    assert_equal away, contest.away_team
  ensure
    CyanideApi::Client.define_method(:contests, original)
  end

  test "refresh_upcoming_matches skips contests from other competitions" do
    @competition.update!(api_id: "396473")
    api_contests = [
      { "contest_id" => 2726554, "competition_id" => 396473, "round" => 2, "status" => "scheduled", "opponents" => [] },
      { "contest_id" => 2712556, "competition_id" => 394358, "round" => 9, "status" => "scheduled", "opponents" => [] }
    ]
    original = CyanideApi::Client.instance_method(:contests)
    CyanideApi::Client.define_method(:contests) { |**| { "upcoming_matches" => api_contests } }

    assert @competition.refresh_upcoming_matches
    assert_equal 1, @competition.contests.count
    assert_equal "2726554", @competition.contests.first.api_id
  ensure
    CyanideApi::Client.define_method(:contests, original)
  end

  test "refresh_upcoming_matches skips contests whose match already exists and removes stale contest" do
    @competition.contests.create!(api_id: "cn-played", round: 4, status: "scheduled")
    @competition.matches.create!(api_id: "abc-123", started: Time.zone.parse("2026-08-23 12:44:10"), round: 4)
    api_contests = [
      { "contest_id" => "cn-played", "round" => 4, "status" => "scheduled", "match_uuid" => "abc-123", "opponents" => [] },
      { "contest_id" => "cn-fresh", "round" => 5, "status" => "scheduled", "match_uuid" => nil, "opponents" => [] }
    ]
    original = CyanideApi::Client.instance_method(:contests)
    CyanideApi::Client.define_method(:contests) { |**| { "upcoming_matches" => api_contests } }

    assert @competition.refresh_upcoming_matches
    assert_equal 1, @competition.contests.count
    assert_equal "cn-fresh", @competition.contests.first.api_id
    refute @competition.contests.exists?(api_id: "cn-played")
  ensure
    CyanideApi::Client.define_method(:contests, original)
  end

  test "refresh_upcoming_matches keeps contests whose match does not exist yet" do
    api_contests = [
      { "contest_id" => "cn-in-progress", "round" => 4, "status" => "InProgress", "match_uuid" => "not-synced-yet", "opponents" => [] }
    ]
    original = CyanideApi::Client.instance_method(:contests)
    CyanideApi::Client.define_method(:contests) { |**| { "upcoming_matches" => api_contests } }

    assert @competition.refresh_upcoming_matches
    assert_equal 1, @competition.contests.count
    assert_equal "cn-in-progress", @competition.contests.first.api_id
  ensure
    CyanideApi::Client.define_method(:contests, original)
  end

  test "refresh_upcoming_matches skips played contests regardless of case" do
    api_contests = [
      { "contest_id" => "cn-001", "round" => 3, "status" => "Played", "opponents" => [] },
      { "contest_id" => "cn-002", "round" => 3, "status" => "VALIDATED", "opponents" => [] },
      { "contest_id" => "cn-003", "round" => 3, "status" => "Scheduled", "opponents" => [] }
    ]
    original = CyanideApi::Client.instance_method(:contests)
    CyanideApi::Client.define_method(:contests) { |**| { "upcoming_matches" => api_contests } }

    assert @competition.refresh_upcoming_matches
    assert_equal 1, @competition.contests.count
    assert_equal "cn-003", @competition.contests.first.api_id
  ensure
    CyanideApi::Client.define_method(:contests, original)
  end

  test "calculate_team_stats coerces string casualty values from the API" do
    team = teams(:cackling_furies)
    @competition.competition_teams.create!(team: team)
    match = @competition.matches.create!(api_id: "stats-1", started: Time.zone.now)
    match.match_teams.create!(team: team, result: :win, score: 2, conceded: 1,
      api_data: { "inflictedcasualties" => "3", "sustainedcasualties" => "1" })

    @competition.calculate_team_stats

    ct = @competition.competition_teams.find_by(team: team)
    assert_equal 2, ct.touchdowns_made
    assert_equal 1, ct.touchdowns_sustained
    assert_equal 3, ct.casualties_made
    assert_equal 1, ct.casualties_sustained
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
        { "team" => { "id" => "id-101", "name" => "Cackling Furies", "rank" => 1, "w/d/l" => "6/1/1", "tv" => 1100 }, "score" => 1850 },
        { "team" => { "id" => "id-102", "name" => "Razorback Raiders", "rank" => 2, "w/d/l" => "4/2/3", "tv" => 1250 }, "score" => 1720 }
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
    assert_equal 1100, team1.reload.value

    ct2.reload
    assert_equal 2, ct2.position
    assert_equal 9, ct2.matches
    assert_equal 4, ct2.wins
    assert_equal 2, ct2.draws
    assert_equal 3, ct2.losses
    assert_equal 14, ct2.points
    assert_equal 1720, ct2.score
    assert_equal 1250, team2.reload.value
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

  test "refresh_upcoming_matches prefers competition_round and stores live flag" do
    home = Team.create!(name: "Cackling Furies", slug: "cackling-furies", api_id: "id-101")
    away = Team.create!(name: "Razorback Raiders", slug: "razorback-raiders", api_id: "id-102")
    api_contests = [
      { "contest_id" => "cn-live", "match_id" => "mc-live", "competition_round" => 2, "round" => 99,
        "contest_status" => "InProgress", "live" => 1, "match_date" => nil,
        "opponents" => [{ "team" => { "id" => "id-101", "score" => 2 } }, { "team" => { "id" => "id-102", "score" => 0 } }] }
    ]
    original = CyanideApi::Client.instance_method(:contests)
    CyanideApi::Client.define_method(:contests) { |**| { "contests" => api_contests } }

    @competition.refresh_upcoming_matches
    contest = @competition.contests.find_by(api_id: "cn-live")
    assert_equal 2, contest.round
    assert contest.live?
    assert_equal 2, contest.home_score
    assert_equal 0, contest.away_score
  ensure
    CyanideApi::Client.define_method(:contests, original)
  end

  test "refresh_upcoming_matches skips contests whose game_id already played" do
    @competition.matches.create!(api_id: "game-1", started: 1.day.ago, finished: 1.day.ago + 2.hours, round: 1)
    api_contests = [
      { "contest_id" => "cn-001", "match_id" => "mc-001", "game_id" => "game-1",
        "competition_round" => 1, "contest_status" => "InProgress", "opponents" => [] }
    ]
    original = CyanideApi::Client.instance_method(:contests)
    CyanideApi::Client.define_method(:contests) { |**| { "contests" => api_contests } }

    @competition.refresh_upcoming_matches
    assert_empty @competition.contests.where(api_id: "cn-001")
  ensure
    CyanideApi::Client.define_method(:contests, original)
  end

  test "expected_rounds is teams minus one for even round-robin" do
    # rebell_season_15 fixture is round_robin with 2 teams
    assert_equal 1, competitions(:rebell_season_15).expected_rounds
  end

  test "expected_rounds equals team count for odd round-robin" do
    # @competition from setup is round_robin with no teams yet
    %w[third fourth fifth].each do |slug|
      @competition.competition_teams.create!(team: Team.create!(name: slug.capitalize, slug: slug))
    end
    assert_equal 3, @competition.expected_rounds
  end

  test "expected_rounds is nil for non round-robin" do
    @competition.update!(format: :single_elimination)
    assert_nil @competition.expected_rounds
  end

  test "schedule merges matches and contests and appends TBD rounds" do
    # @competition is round_robin with no teams -> no expected rounds
    match = @competition.matches.create!(api_id: "m-sched", started: 1.day.ago, finished: 1.day.ago + 2.hours, round: 1)
    contest = @competition.contests.create!(api_id: "cn-sched", round: 2, status: "Scheduled")

    rows = @competition.schedule
    assert_equal [1, 2], rows.map(&:first)
    assert_equal [match.id], rows.first[1][:matches].map(&:id)
    assert_empty rows.first[1][:contests]
    assert_empty rows.second[1][:matches]
    assert_equal [contest.id], rows.second[1][:contests].map(&:id)
  end

  test "schedule pads future rounds up to expected_rounds" do
    @competition.matches.create!(api_id: "m-sched", started: 1.day.ago, finished: 1.day.ago + 2.hours, round: 1)
    10.times { |i| @competition.competition_teams.create!(team: Team.create!(name: "Extra #{i}", slug: "extra-#{i}")) }
    assert_equal 9, @competition.expected_rounds

    rows = @competition.schedule
    assert_equal (1..9).to_a, rows.map(&:first)
    assert_equal 1, rows.first[1][:matches].size
    assert_empty rows[1][1][:matches]
    assert_empty rows[1][1][:contests]
  end
end
