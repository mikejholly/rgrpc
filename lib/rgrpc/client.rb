# frozen_string_literal: true

require 'google/protobuf'
require 'http/2'
require 'logger'
require 'socket'
require 'thread'
require 'stringio'
require 'zlib'

Thread.abort_on_exception = true

module RGRPC
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

    def rpc(path, message, returns: klass, timeout: 10_000)
      @mutex.synchronize do
        connect unless @connected
      end

      stream = @conn.new_stream
      done = false
      body = ''
      res = {}

      head = {
        ':scheme' => 'http',
        ':method' => 'POST',
        ':authority' => [@host, @port].join(':'),
        ':path' => path,
        'grpc-timeout' => "#{timeout}m",
        'content-type' => 'application/grpc+proto',
        'user-agent' => 'grpc-ruby-rgrpc/' + RGRPC::VERSION,
        'grpc-encoding' => 'gzip'
      }

      stream.on(:headers) do |h|
        @logger.debug("received headers #{h.inspect}")
        res = Hash[*h.flatten]
      end

      stream.on(:data) do |d|
        @logger.debug("received data chunk #{d}")
        body += d
      end

      stream.on(:close) do
        @logger.debug('stream closed')
        done = true
      end

      stream.on(:half_close) { @logger.debug('closing client end of stream') }
      stream.headers(head, end_stream: false)
      encoded = message.class.encode(message)
      stream.data(Zlib::Deflate.deflate(encoded))

      sleep 0.001 until done

      [res, returns.decode(Zlib::Inflate.inflate(body))]
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

      Thread.new do
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
  end
end
