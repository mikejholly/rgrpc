# frozen_string_literal: true

module RGRPC
  # Abstacts some of the more complex HTTP2 stream logic
  class HTTP2Client
    def initialize(host, port, tls_config: nil, logger: Logger.new($stdout))
      @host = host
      @port = port
      @connected = false
      @tls_config = tls_config
      @logger = logger
      @write_thread = nil
      @read_thread = nil
      @write_queue = Queue.new
      @closing = false
    end

    def connect
      @logger.info("connecting to #{@host}:#{@port}")

      @sock = tcp_socket
      @conn = HTTP2::Client.new

      @conn.on(:frame) do |bytes|
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

      start_read_thread
      start_write_thread

      @connected = true
    end

    def request(req)
      raise 'not connected' unless @connected

      stream = @conn.new_stream

      future = Concurrent::Future.new {}

      head = {}
      data = StringIO.new

      stream.on(:headers) do |h|
        @logger.debug("received headers #{h.inspect}")
        head = Hash[*h.flatten]
      end

      stream.on(:data) do |d|
        @logger.debug("received data chunk of size #{d.length}")
        data << d
      end

      stream.on(:close) do
        @logger.debug('stream closed')
        future.set(Response.new(head, data.string))
      end

      stream.on(:half_close) do
        @logger.debug('closing client end of stream')
      end

      stream.headers(req.headers, end_stream: false)
      stream.data(req.data)

      future
    end

    def close
      @closing = true
      [@read_thread, @write_thread].map(&:join)
      @sock.close
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
          @logger.debug('loop read')
          begin
            break if @closing
            data = @sock.read_nonblock(1024)
            @conn << data
          rescue IO::WaitReadable
            break if @closing
            IO.select([@sock])
            retry
          rescue IO::WaitWritable
            break if @closing
            IO.select(nil, [@sock])
            retry
          end
        end
      end
    end

    def start_write_thread
      @write_thread = Thread.new do
        loop do
          if @closing
            @logger.debug('exiting write thread')
            break
          end
          @write_queue.pop&.call
        end
      end
    end
  end
end
