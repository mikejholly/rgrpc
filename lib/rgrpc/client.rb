# frozen_string_literal: true

require 'google/protobuf'
require 'stringio'
require 'zlib'
require 'concurrent'

require_relative 'response'

Thread.abort_on_exception = true

module RGRPC
  # Main gRPC client interface
  class Client
    def initialize(host, port, tls_config: nil, logger: Logger.new($stdout))
      @client = HTTP2Client.new(host, port, tls_config: tls_config, logger: logger)
      @logger = logger
    end

    def connect
      @client.connect
    end

    def rpc(path, message, coder, timeout: 10_000)
      encoded = coder.encode(message)
      gzipped = Zlib::Deflate.deflate(encoded)

      req = Request.new(path, gzipped)
      req.method = 'POST'
      req.authority = [@host, @port].join(':')
      req.path = path
      req.content_type = 'application/grpc+proto'
      req.user_agent = 'grpc-ruby-rgrpc/' + RGRPC::VERSION
      req.header('grpc-timeout', "#{timeout}m")

      res = @client.request(req).value

      @logger.debug(res.inspect)

      unzipped = Zlib::Inflate.inflate(res.data)
      decoded = coder.decode(unzipped)

      [res.header('grpc-status').to_i, decoded]
    end

    def close
      @client.close
    end
  end
end
