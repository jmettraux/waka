
require 'json'
require 'net/http'


module Waka

  BASE_URI = 'https://api.wanikani.com/v2/'

  class << self

    def load_token(path)

      File.read(path).strip
    end
  end

  class Session

    def initialize(path_or_token)

      @token = path_or_token
      @token = File.read(path_or_token).strip if path_or_token.match(/\//)
    end

    def summary

      get(:summary)
    end

    protected

    def get(*as)

      uri = URI(BASE_URI + as.join('/'))

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      req = Net::HTTP::Get.new(uri.to_s)
      req.instance_eval { @header.clear }
      def req.set_header(k, v); @header[k] = [ v ]; end

      req.set_header('User-Agent', "#{self.class}")
      req.set_header('Accept', 'application/json')
      req.set_header('Authorization', "Bearer #{@token}")

      res = http.request(req)

      fail "request returned a #{res.class} and not a Net::HTTPResponse" \
        unless res.is_a?(Net::HTTPResponse)

      JSON.parse(res.body)
    end
  end

  module Reports

    class << self
    end
  end
end

