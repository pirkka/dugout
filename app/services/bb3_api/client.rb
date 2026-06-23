require "net/http"
require "json"
require "uri"

module Bb3Api
  class Error < StandardError; end
  class NotFoundError < Error; end
  class RateLimitError < Error; end

  class Client
    BASE_URL = "https://web.cyanide-studio.com/ws/bb3".freeze

    def initialize(api_key: nil)
      @api_key = api_key || Rails.application.credentials.bb3_api_key
    end

    def league(name: nil, id: nil, platform: nil)
      params = { bb: 3 }
      params[:league_name] = name if name
      params[:league_id] = id if id
      params[:platform] = platform if platform

      get("/league/", params)
    end

    private

    def get(path, params = {})
      params[:key] = @api_key
      uri = URI("#{BASE_URL}#{path}")
      uri.query = URI.encode_www_form(params) unless params.empty?

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
