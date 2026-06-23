require "test_helper"

module CyanideApi
  class ClientTest < ActiveSupport::TestCase
    setup do
      @client = Client.new(api_key: "test_key")
    end

    test "constructs league request with name and platform" do
      original = Client.instance_method(:get)
      Client.define_method(:get) { |*| { "name" => "Test League", "id" => 1 } }

      data = @client.league(name: "Test League", platform: "pc")
      assert_equal "Test League", data["name"]
    ensure
      Client.define_method(:get, original)
    end

    test "raises NotFoundError on 404" do
      original = Client.instance_method(:get)
      Client.define_method(:get) { |*| raise NotFoundError }

      assert_raises(NotFoundError) { @client.league(name: "Unknown") }
    ensure
      Client.define_method(:get, original)
    end

    test "raises RateLimitError on 429" do
      original = Client.instance_method(:get)
      Client.define_method(:get) { |*| raise RateLimitError }

      assert_raises(RateLimitError) { @client.league(name: "Test") }
    ensure
      Client.define_method(:get, original)
    end

    test "raises Error on other status codes" do
      original = Client.instance_method(:get)
      Client.define_method(:get) { |*| raise Error, "API request failed with status 502: Bad Gateway" }

      assert_raises(Error) { @client.league(name: "Test") }
    ensure
      Client.define_method(:get, original)
    end

    test "constructs competitions request with league params" do
      response = { "competitions" => [{ "name" => "Season 1" }] }
      original = Client.instance_method(:get)
      Client.define_method(:get) { |*| response }

      data = @client.competitions(league_name: "Test League", platform: "pc")
      assert_equal "Season 1", data["competitions"].first["name"]
    ensure
      Client.define_method(:get, original)
    end

    test "raises NotFoundError on competitions 404" do
      original = Client.instance_method(:get)
      Client.define_method(:get) { |*| raise NotFoundError }

      assert_raises(NotFoundError) { @client.competitions(league_name: "Unknown") }
    ensure
      Client.define_method(:get, original)
    end

    test "constructs teams request with competition params" do
      response = { "teams" => [{ "name" => "Cackling Furies" }] }
      original = Client.instance_method(:get)
      Client.define_method(:get) { |*| response }

      data = @client.teams(competition_name: "Season 1", platform: "pc")
      assert_equal "Cackling Furies", data["teams"].first["name"]
    ensure
      Client.define_method(:get, original)
    end

    test "raises NotFoundError on teams 404" do
      original = Client.instance_method(:get)
      Client.define_method(:get) { |*| raise NotFoundError }

      assert_raises(NotFoundError) { @client.teams(competition_name: "Unknown") }
    ensure
      Client.define_method(:get, original)
    end

    test "constructs matches request with competition params" do
      response = { "matches" => [{ "uuid" => "abc-123", "home_team" => "Furies" }] }
      original = Client.instance_method(:get)
      Client.define_method(:get) { |*| response }

      data = @client.matches(competition_name: "Season 1", platform: "pc")
      assert_equal "abc-123", data["matches"].first["uuid"]
    ensure
      Client.define_method(:get, original)
    end

    test "raises NotFoundError on matches 404" do
      original = Client.instance_method(:get)
      Client.define_method(:get) { |*| raise NotFoundError }

      assert_raises(NotFoundError) { @client.matches(competition_name: "Unknown") }
    ensure
      Client.define_method(:get, original)
    end
  end
end
