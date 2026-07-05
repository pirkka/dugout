require "net/http"
require "json"
require "uri"

module CyanideApi
  class Error < StandardError; end
  class NotFoundError < Error; end
  class RateLimitError < Error; end

  class Client
    BASE_URL = "https://web.cyanide-studio.com/ws".freeze

    def initialize(api_key: nil)
      @api_key = api_key || Rails.application.credentials.cyanide_api_key
    end

    private

    def base_url(game_version)
      "#{BASE_URL}/bb#{api_bb_value(game_version)}"
    end

    public

    def league(name: nil, id: nil, platform: nil, game_version: :bb3)
      params = { bb: api_bb_value(game_version), start: Time.now-100.years, limit: 1000 }
      params[:league_name] = name if name
      params[:league_id] = id if id
      params[:platform] = platform if platform

      get("/league/", params, game_version)
    end

    def competitions(league_name: nil, league_id: nil, platform: nil, game_version: :bb3)
      params = { bb: api_bb_value(game_version), start: Time.now-100.years, limit: 1000 }
      params[:league_id] = league_id if league_id
      params[:platform] = platform if platform

      get("/competitions/", params, game_version)
    end

    def teams(competition_name: nil, competition_id: nil, league_name: nil, league_id: nil, platform: nil, game_version: :bb3, limit: nil)
      params = { bb: api_bb_value(game_version), start: Time.now-100.years, limit: 1000 }
      params[:competition_id] = competition_id if competition_id
      params[:league_id] = league_id if league_id
      params[:platform] = platform if platform
      params[:limit] = limit if limit

      get("/teams/", params, game_version)
    end

    def matches(competition_name: nil, competition_id: nil, league_name: nil, league_id: nil, platform: nil, game_version: :bb3, limit: nil, start: nil, end_date: nil)
      params = { bb: api_bb_value(game_version), start: Time.now-100.years, limit: 1000 }
      params[:competition_id] = competition_id if competition_id
      params[:league_id] = league_id if league_id
      params[:platform] = platform if platform
      params[:limit] = limit if limit
      params[:start] = start if start
      params[:end] = end_date if end_date

      get("/matches/", params, game_version)
    end

    def ladder(competition_name: nil, competition_id: nil, game_version: :bb3)
      params = {}
      params = { bb: api_bb_value(game_version), start: Time.now-100.years, limit: 1000 }
      params[:competition_name] = competition_name if competition_name
      params[:competition_id] = competition_id if competition_id
      get("/ladder/", params, game_version)
    end

    private

    def api_bb_value(game_version)
      case game_version.to_s
      when "bb2" then 2
      when "bb3" then 3
      else 3
      end
    end

    def get(path, params = {}, game_version = :bb3)
      params[:key] = @api_key
      uri = URI("#{base_url(game_version)}#{path}")
      uri.query = URI.encode_www_form(params) unless params.empty?

      puts uri

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 10

      request = Net::HTTP::Get.new(uri)
      response = http.request(request)

      case response
      when Net::HTTPNotFound
        raise NotFoundError, "Resource not found"
      when Net::HTTPTooManyRequests
        raise RateLimitError, "API rate limit exceeded"
      when Net::HTTPOK
        JSON.parse(response.body)
      else
        raise Error, "API request failed with status #{response.code}: #{response.body}"
      end
    end
  end
end
