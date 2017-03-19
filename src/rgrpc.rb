# frozen_string_literal: true

require 'google/protobuf'
require 'http/2'
require 'logger'
require 'socket'
require 'thread'

Thread.abort_on_exception = true

module RGrpc
  # GRPC Client
  class Client
    def initialize(host:,
                   port:,
                   logger: Logger.new($stdout))
      @host = host
      @port = port
      @logger = logger
      @connected = false
      @sock = nil
      @conn = nil
      @mutex = Mutex.new
    end

    def send
      connect unless @connected

      stream = @conn.new_stream
      done = false
      body = StringIO.new
      res = {}

      head = {
        ':scheme' => 'http',
        ':method' => 'POST',
        ':authority' => [@host, @port].join(':'),
        ':path' => '/',
        'accept' => '*/*'
      }

      stream.on(:headers) do |h|
        @logger.debug("received headers #{h.inspect}")
        res = Hash[*h.flatten]
      end

      stream.on(:data) do |d|
        @logger.debug("received data chunk #{d}")
        body << d
      end

      stream.on(:close) do
        @logger.debug('stream closed')
        done = true
      end

      stream.on(:half_close) { @logger.debug('closing client end of stream') }

      stream.headers(head, end_stream: false)
      stream.data('Hello World!')

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

      [res, body.string]
    end

    private

    def connect
      @logger.info("connecting to #{@host}:#{@port}")

      @sock = TCPSocket.new(@host, @port)
      @conn = HTTP2::Client.new

      @conn.on(:frame) do |bytes|
        @sock.print(bytes)
        @sock.flush
      end

      @conn.on(:frame_sent) do |frame|
        @logger.debug("frame sent #{frame.inspect}")
      end

      @conn.on(:frame_received) do |frame|
        @logger.debug("frame received #{frame.inspect}")
      end

      @connected = true

    end
  end

  # GRPC Server
  class Server
    def initialize(host:,
                   port: 443,
                   logger: Logger.new($stdout))
      @host = host
      @port = port
      @logger = logger
      @server = nil
    end

    def start
      connect

      @logger.info('entering main loop')

      loop do
        Thread.new(@server.accept) do |sock|
          @logger.info("accepted connection")

          conn = HTTP2::Server.new

          conn.on(:frame) do |bytes|
            sock.sendmsg(bytes)
          end

          conn.on(:frame_sent) do |frame|
            @logger.debug("sent frame: #{frame.inspect}")
          end

          conn.on(:frame_received) do |frame|
            @logger.debug("received frame: #{frame}")
          end

          conn.on(:stream) do |stream|
            buf = StringIO.new
            req = {}

            stream.on(:active) { @logger.debug('client opened new stream') }
            stream.on(:close)  { @logger.debug('stream closed') }

            stream.on(:headers) do |h|
              req = Hash[*h.flatten]
              @logger.debug("request headers #{h}")
            end

            stream.on(:data) do |d|
              @logger.debug("request data #{d}")
              buf << d
            end

            stream.on(:half_close) do
              @logger.info('sending response')

              body = 'HELLO TO YOU FRIEND!'
              stream.headers({ ':status' => '200',
                               'content-length' => body.bytesize.to_s,
                               'content-type' => 'text/plain' },
                             end_stream: false)
              stream.data(body)
            end
          end

          loop do
            begin
              data = sock.readpartial(1024)
              conn << data
            rescue HTTP2::Error::ProtocolError => e
              @logger.warn("#{e.class} #{e.message}")
            rescue EOFError
              @logger.info('client disconnected')
              break
            end
          end
        end
      end
    end

    private

    def connect
      @logger.info("creating socker server on #{@host}:#{@port}")
      @server = TCPServer.new(@host, @port)
    end
  end
end
