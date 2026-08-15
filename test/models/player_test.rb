require "test_helper"

class PlayerTest < ActiveSupport::TestCase
  test "resolve creates a new player by team and number" do
    player = Player.resolve(teams(:cackling_furies), number: 1, name: "Ilona 'The Queen'")

    assert player.persisted?
    assert_equal teams(:cackling_furies), player.team
    assert_equal 1, player.number
    assert_equal "Ilona 'The Queen'", player.name
  end

  test "resolve reuses by name across a renumber" do
    player = Player.create!(team: teams(:cackling_furies), number: 2, name: "Jeffrey Dahmer")

    resolved = Player.resolve(teams(:cackling_furies), number: 1, name: "Jeffrey Dahmer")

    assert_equal player, resolved
    assert_equal 1, resolved.number
  end

  test "resolve reuses by number on a rename" do
    player = Player.create!(team: teams(:cackling_furies), number: 2, name: "John Doe")

    resolved = Player.resolve(teams(:cackling_furies), number: 2, name: "Jane Doe")

    assert_equal player, resolved
    assert_equal "Jane Doe", resolved.name
  end

  test "resolve frees a number held by a departed player" do
    departed = Player.create!(team: teams(:cackling_furies), number: 2, name: "Ted Bundy")
    Player.create!(team: teams(:cackling_furies), number: 3, name: "Jeffrey Dahmer")

    resolved = Player.resolve(teams(:cackling_furies), number: 2, name: "Jeffrey Dahmer")

    assert_equal "Jeffrey Dahmer", resolved.name
    assert_equal 2, resolved.number
    assert_nil departed.reload.number
  end

  test "resolve is scoped to team" do
    a = Player.resolve(teams(:cackling_furies), number: 1, name: "Dup")
    b = Player.resolve(teams(:razorback_raiders), number: 1, name: "Dup")

    assert_not_equal a, b
  end

  test "resolve does not rename a dead player" do
    team = teams(:cackling_furies)
    dead = Player.resolve(team, number: 2, name: "Lautapoika")
    PlayerVersion.create!(player: dead, match: matches(:season_opener), name: "Lautapoika", number: 2, status: Player::DEAD)

    successor = Player.resolve(team, number: 2, name: "Yritysjargon Titteli")

    assert_equal "Lautapoika", dead.reload.name
    assert_nil dead.reload.number
    assert_equal "Yritysjargon Titteli", successor.name
    assert_equal 2, successor.number
  end

  test "compute_status is active for a player in the latest match" do
    team = teams(:cackling_furies)
    MatchTeam.create!(match: matches(:final_showdown), team: team, home: true)
    player = Player.create!(team: team, number: 1, name: "Active")
    PlayerVersion.create!(player: player, match: matches(:final_showdown), name: "Active", number: 1, status: "normal")

    assert_equal Player::ACTIVE, player.compute_status
  end

  test "compute_status is dead when a version has dead status" do
    player = Player.create!(team: teams(:cackling_furies), number: 1, name: "Dead")
    PlayerVersion.create!(player: player, match: matches(:final_showdown), name: "Dead", number: 1, status: Player::DEAD)

    assert_equal Player::DEAD, player.compute_status
  end

  test "compute_status is mng for a miss-next-game injury in the latest match" do
    team = teams(:cackling_furies)
    MatchTeam.create!(match: matches(:final_showdown), team: team, home: true)
    player = Player.create!(team: team, number: 1, name: "Mng")
    PlayerVersion.create!(player: player, match: matches(:final_showdown), name: "Mng", number: 1, status: "injured", injury_type: Player::MNG)

    assert_equal Player::MNG, player.compute_status
  end

  test "compute_status clears mng once a later match exists" do
    team = teams(:cackling_furies)
    mng_match = matches(:final_showdown)
    later = Match.create!(competition: competitions(:rebell_season_15), api_id: "m003", started: Time.zone.parse("2026-06-25 19:00:00"), finished: Time.zone.parse("2026-06-25 20:30:00"), round: 3)
    MatchTeam.create!(match: later, team: team, home: true)
    MatchTeam.create!(match: later, team: teams(:razorback_raiders), home: false)

    player = Player.create!(team: team, number: 1, name: "Recovered")
    PlayerVersion.create!(player: player, match: mng_match, name: "Recovered", number: 1, status: "injured", injury_type: Player::MNG)

    assert_equal Player::ACTIVE, player.compute_status
  end

  test "compute_status is fired for a freed number" do
    player = Player.create!(team: teams(:cackling_furies), number: 1, name: "Gone")
    PlayerVersion.create!(player: player, match: matches(:season_opener), name: "Gone", number: 1, status: "normal")
    player.update!(number: nil)

    assert_equal Player::FIRED, player.compute_status
  end

  test "compute_status is fired after two consecutive missed matches" do
    team = teams(:cackling_furies)
    matches = [1, 2, 3].map do |round|
      Match.create!(
        competition: competitions(:rebell_season_15),
        api_id: "m10#{round}",
        started: Time.zone.parse("2026-06-2#{round} 19:00:00"),
        finished: Time.zone.parse("2026-06-2#{round} 20:30:00"),
        round: round
      )
    end
    matches.each do |match|
      MatchTeam.create!(match: match, team: team, home: true)
      MatchTeam.create!(match: match, team: teams(:razorback_raiders), home: false)
    end

    player = Player.create!(team: team, number: 1, name: "Fired")
    PlayerVersion.create!(player: player, match: matches[0], name: "Fired", number: 1, status: "normal")
    filler = Player.create!(team: team, number: 2, name: "Filler")
    PlayerVersion.create!(player: filler, match: matches[1], name: "Filler", number: 2, status: "normal")
    PlayerVersion.create!(player: filler, match: matches[2], name: "Filler", number: 2, status: "normal")

    assert_equal Player::FIRED, player.compute_status
  end
end
