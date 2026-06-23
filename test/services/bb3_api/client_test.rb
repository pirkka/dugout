require "test_helper"

module Bb3Api
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
  end
end
