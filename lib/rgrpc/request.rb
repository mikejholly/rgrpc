# frozen_string_literal: true

module RGRPC
  # Models a gRPC request
  class Request
    def initialize(host, port, path, message, coder, timeout = 0)
      @host = host
      @port = port
      @path = path
      @message = message
      @coder = coder
      @timeout = timeout
    end

    def message
      encoded = @coder.encode(@message)
      Zlib::Deflate.deflate(encoded)
    end

    def headers
      { ':scheme' => 'http',
        ':method' => 'POST',
        ':authority' => [@host, @port].join(':'),
        ':path' => @path,
        'grpc-timeout' => "#{@timeout}m",
        'content-type' => 'application/grpc+proto',
        'user-agent' => 'grpc-ruby-rgrpc/' + RGRPC::VERSION,
        'grpc-encoding' => 'gzip' }
    end
  end
end
