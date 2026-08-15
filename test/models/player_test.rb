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
end
