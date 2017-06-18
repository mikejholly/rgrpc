# frozen_string_literal: true

module RGRPC
  # Creates a new insecure TCP socket
  class TCPSocketBuilder
    def initialize(host, port)
      @host = host
      @port = port
    end

    def build
      TCPSocket.new(@host, @port)
    end
  end
end
