# frozen_string_literal: true

module GRPC
  # Models a gRPC response
  class Response
    def initialize(headers, message, coder)
      @headers = headers
      @message = message
      @coder = coder
    end

    def headers
      @headers
    end

    def message
      decoded = coder.decode(@message)
      Zlib::Inflate.inflate(decoded)
    end
  end
end
