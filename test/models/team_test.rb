require "test_helper"

class TeamTest < ActiveSupport::TestCase
  test "upcoming_contests returns contests where the team is home or away" do
    team = teams(:cackling_furies)
    away = teams(:razorback_raiders)
    competition = competitions(:rebell_season_15)
    home_contest = contests(:upcoming_round_1)
    away_contest = competition.contests.create!(api_id: "cn-away", match_id: "mc-away", round: 4, status: "Scheduled", away_team: team)
    other = competition.contests.create!(api_id: "cn-other", match_id: "mc-other", round: 5, status: "Scheduled")

    assert_equal [home_contest, away_contest], team.upcoming_contests
    assert_equal [home_contest], away.upcoming_contests
    refute_includes team.upcoming_contests, other
  end

  test "upcoming_contests excludes contests from other competitions" do
    team = teams(:cackling_furies)
    other_comp = leagues(:xfactor).competitions.create!(name: "Other Cup", slug: "other-cup", format: :round_robin, platform: :pc)
    other_comp.contests.create!(api_id: "cn-other-comp", match_id: "mc-oc", round: 1, status: "Scheduled", home_team: team)

    assert_equal [contests(:upcoming_round_1)], team.upcoming_contests
  end

  test "current_roster returns latest version per player ordered by number" do
    team = teams(:cackling_furies)
    first_match = matches(:season_opener)
    later_match = matches(:final_showdown)

    ilona = Player.resolve(team, number: 1, name: "Ilona")
    ratty = Player.resolve(team, number: 2, name: "Ratty")
    MatchPlayer.create!(player: ilona, match: first_match, name: "Ilona", number: 1, skills: ["Block"])
    MatchPlayer.create!(player: ilona, match: later_match, name: "Ilona", number: 1, skills: ["Block", "Guard"])
    MatchPlayer.create!(player: ratty, match: later_match, name: "Ratty", number: 2, skills: [])

    roster = team.current_roster

    assert_equal [1, 2], roster.map { |v| v.player.number }
    assert_equal ["Block", "Guard"], roster.first.skills
    assert_equal ratty, roster.second.player
  end

  test "current_roster excludes departed players by status" do
    team = teams(:cackling_furies)
    departed = Player.resolve(team, number: 3, name: "Departed")
    MatchPlayer.create!(player: departed, match: matches(:season_opener), name: "Departed", number: 3, skills: [])
    departed.update!(status: Player::FIRED)

    assert_equal [], team.current_roster
  end

  test "current_roster includes mng players" do
    team = teams(:cackling_furies)
    mng_player = Player.resolve(team, number: 1, name: "Mng")
    MatchPlayer.create!(player: mng_player, match: matches(:season_opener), name: "Mng", number: 1, skills: [])
    mng_player.update!(status: Player::MNG)

    assert_equal [mng_player], team.current_roster.map(&:player)
  end

  test "departed_roster returns latest version per departed player" do
    team = teams(:cackling_furies)
    first_match = matches(:season_opener)
    later_match = matches(:final_showdown)

    fired = Player.resolve(team, number: 3, name: "Fired")
    dead = Player.resolve(team, number: 4, name: "Dead")
    active = Player.resolve(team, number: 5, name: "Active")
    MatchPlayer.create!(player: fired, match: first_match, name: "Fired", number: 3, skills: ["Block"])
    MatchPlayer.create!(player: fired, match: later_match, name: "Fired", number: 3, skills: ["Block", "Guard"])
    MatchPlayer.create!(player: dead, match: later_match, name: "Dead", number: 4, skills: [])
    MatchPlayer.create!(player: active, match: later_match, name: "Active", number: 5, skills: [])
    fired.update!(status: Player::FIRED)
    dead.update!(status: Player::DEAD)

    departed = team.departed_roster

    assert_equal [fired, dead], departed.map(&:player)
    assert_equal ["Block", "Guard"], departed.first.skills
    refute_includes departed.map(&:player), active
  end

  test "current_roster is empty without player versions" do
    assert_equal [], teams(:razorback_raiders).current_roster
  end
end
