# frozen_string_literal: true

module RGRPC
  # Models a HTTP2 response
  class Response
    attr_accessor :headers, :data

    def initialize(headers, data)
      @headers = headers
      @data = data
    end

    def header(name)
      @headers[name]
    end
  end
end
