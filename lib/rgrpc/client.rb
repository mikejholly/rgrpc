# frozen_string_literal: true

require 'google/protobuf'
require 'http/2'
require 'logger'
require 'socket'
require 'thread'

Thread.abort_on_exception = true

module RGrpc
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

      sleep 0.005 until done

      [res, body.string]
    end

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
