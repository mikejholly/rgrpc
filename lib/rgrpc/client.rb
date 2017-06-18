# frozen_string_literal: true

require 'google/protobuf'
require 'http/2'
require 'logger'
require 'socket'
require 'thread'
require 'stringio'
require 'zlib'
require 'concurrent'

Thread.abort_on_exception = true

module RGRPC
  # Main gRPC client interface
  class Client
    Response = Struct.new(:headers, :body)

    def initialize(host,
                   port,
                   logger: Logger.new($stdout),
                   tls_config: nil)
      @host = host
      @port = port
      @logger = logger
      @connected = false
      @sock = nil
      @conn = nil
      @mutex = Mutex.new
      @tls_config = tls_config

      @write_queue = Queue.new
      @read_thread = nil
      @write_thread = nil
    end

    def rpc(path, message, coder, timeout = 2_000)
      @mutex.synchronize do
        connect unless @connected
      end

      stream = @conn.new_stream
      request = Request.new(@host, @port, path, message, coder, timeout)
      future = Concurrent::Future.new {}

      headers = {}
      message = StringIO.new

      stream.on(:headers) do |h|
        @logger.debug("received headers #{h.inspect}")
        headers = Hash[*h.flatten]
      end

      stream.on(:data) do |d|
        @logger.debug("received data chunk #{d}")
        message << d
      end

      stream.on(:close) do
        @logger.debug('stream closed')
        future.set(Response.new(headers, message))
      end

      stream.on(:half_close) { @logger.debug('closing client end of stream') }
      stream.headers(request.headers, end_stream: false)

      stream.data(request.message)

      future
    end

    def close
      # TODO
    end

    private

    def tcp_socket
      builder = if @tls_config
                  SecureSocketBuilder.new(@host, @port, @tls_config)
                else
                  TCPSocketBuilder.new(@host, @port)
                end

      builder.build
    end

    def start_read_thread
      @read_thread = Thread.new do
        loop do
          begin
            data = @sock.read_nonblock(1024)
            @conn << data
          rescue IO::WaitReadable
            IO.select([@sock])
            retry
          rescue IO::WaitWritable
            IO.select(nil, [@sock])
            retry
          end
        end
      end
    end

    def start_write_thread
      @write_thread = Thread.new do
        @write_queue.pop&.call
      end
    end

    def connect
      @logger.info("connecting to #{@host}:#{@port}")

      @sock = tcp_socket
      @conn = HTTP2::Client.new

      @conn.on(:frame) do |bytes|
        @logger.debug("writing frame: #{bytes.length} bytes")
        @write_queue << lambda do
          @sock.print(bytes)
          @sock.flush
        end
      end

      @conn.on(:frame_sent) do |frame|
        @logger.debug("frame sent #{frame.inspect}")
      end

      @conn.on(:frame_received) do |frame|
        @logger.debug("frame received #{frame.inspect}")
      end

      @connected = true

      start_read_thread
      start_write_thread
    end
  end
end
