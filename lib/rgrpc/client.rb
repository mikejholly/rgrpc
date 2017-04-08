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
    Response = Struct.new(:headers, :body)

    def initialize(host:,
                   port:,
                   logger: Logger.new($stdout),
                   secure: false,
                   tls_cert: nil,
                   tls_key: nil,
                   tls_ca: nil)
      @host = host
      @port = port
      @logger = logger
      @connected = false
      @sock = nil
      @conn = nil
      @mutex = Mutex.new
      @secure = secure
      @tls_cert = tls_cert
      @tls_key = tls_key
      @tls_ca = tls_ca
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

      Response.new(res, returns.decode(Zlib::Inflate.inflate(body)))
    end

    private

    def tcp_socket
      tcp = TCPSocket.new(@host, @port)
      return tcp unless @secure

      ctx = OpenSSL::SSL::SSLContext.new
      ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE
      ctx.ssl_version = :TLSv1_2
      ctx.client_ca = @tls_ca if @tls_ca

      if @tls_cert && @tls_key
        ctx.cert = OpenSSL::X509::Certificate.new(@tls_cert)
        ctx.key = OpenSSL::PKey::RSA(@tls_key)
      end

      ctx.alpn_protocols = [ALPN_DRAFT]
      ctx.alpn_select_cb = lambda do |protocols|
        @logger.debug("ALPN protocols supported by server: #{protocols}")
        ALPN_DRAFT if protocols.include?(ALPN_DRAFT)
      end

      sock = OpenSSL::SSL::SSLSocket.new(tcp, ctx)
      sock.sync_close = true
      sock.hostname = @host
      sock.connect

      if sock.alpn_protocol != ALPN_DRAFT
        raise "Failed to negotiate #{ALPN_DRAFT} via ALPN"
      end

      sock
    end

    def connect
      @logger.info("connecting to #{@host}:#{@port}")

      @sock = tcp_socket
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
