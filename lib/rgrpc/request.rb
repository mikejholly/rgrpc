# frozen_string_literal: true

module RGRPC
  # Models an HTTP2 request
  class Request
    attr_accessor :path, :data
    attr_reader :headers

    def initialize(path, data)
      @path = path
      @data = data
      @headers = { ':scheme' => 'http' }
    end

    def header(name, value)
      @headers[name] = value
    end

    def content_type=(v)
      @headers['content-type'] = v
    end

    def method=(v)
      @headers[':method'] = v
    end

    def authority=(v)
      @headers[':authority'] = v
    end

    def path=(v)
      @headers[':path'] = v
    end

    def user_agent=(v)
      @headers['user-agent'] = v
    end
  end
end
