require "test_helper"

class LeagueTest < ActiveSupport::TestCase
  setup do
    @league = League.create!(name: "Test League", slug: "test-league", platform: :pc)
  end

  test "refresh_from_api updates league attributes" do
    data = { "name" => "Updated League", "id" => 42, "platform" => "pc" }
    original = Bb3Api::Client.instance_method(:league)
    Bb3Api::Client.define_method(:league) { |**| data }

    assert @league.refresh_from_api
    assert_equal "Updated League", @league.reload.name
    assert_equal 42, @league.api_id
  ensure
    Bb3Api::Client.define_method(:league, original)
  end

  test "refresh_from_api returns false on not found" do
    original = Bb3Api::Client.instance_method(:league)
    Bb3Api::Client.define_method(:league) { |**| raise Bb3Api::NotFoundError }

    refute @league.refresh_from_api
    assert_equal "League not found on API", @league.errors.full_messages.first
  ensure
    Bb3Api::Client.define_method(:league, original)
  end

  test "refresh_from_api returns false on API error" do
    original = Bb3Api::Client.instance_method(:league)
    Bb3Api::Client.define_method(:league) { |**| raise Bb3Api::Error, "Timeout" }

    refute @league.refresh_from_api
    assert_equal "Timeout", @league.errors.full_messages.first
  ensure
    Bb3Api::Client.define_method(:league, original)
  end

  test "refresh_from_api stores raw api_data" do
    response = { "name" => "League", "id" => 1, "extra" => "value" }
    original = Bb3Api::Client.instance_method(:league)
    Bb3Api::Client.define_method(:league) { |**| response }

    @league.refresh_from_api
    assert_equal response, @league.reload.api_data
  ensure
    Bb3Api::Client.define_method(:league, original)
  end
end
