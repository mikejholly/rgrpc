# frozen_string_literal: true

require 'google/protobuf'
require 'http/2'
require 'logger'
require 'socket'
require 'thread'
require 'openssl'

module RGRPC
  class Server
    def initialize(handler:,
                   host:,
                   port: 443,
                   tls_config: nil,
                   logger: Logger.new($stdout))
      @handler = handler
      @host = host
      @port = port
      @logger = logger
      @server = nil
      @tls_config = tls_config
    end

    def listen
      connect

      @logger.info('entering main loop')

      loop do
        Thread.new(@server.accept) { |conn| handle_conn(conn) }
      end
    end

    private

    def handle_conn(sock)
      @logger.info('accepted connection')

      conn = HTTP2::Server.new

      conn.on(:frame) do |bytes|
        sock.is_a?(TCPSocket) ? sock.sendmsg(bytes) : sock.write(bytes)
      end

      conn.on(:frame_sent) do |frame|
        @logger.debug("sent frame: #{frame.inspect}")
      end

      conn.on(:frame_received) do |frame|
        @logger.debug("received frame: #{frame}")
      end

      conn.on(:stream) do |stream|
        on_stream(stream)
      end

      read_sock(conn, sock)
    end

    def read_sock(conn, sock)
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

    def on_stream(stream)
      body = ''
      head = {}

      stream.on(:active) { @logger.debug('client opened new stream') }
      stream.on(:close)  { @logger.debug('stream closed') }

      stream.on(:headers) do |h|
        head = Hash[*h.flatten]
        @logger.debug("request headers #{h}")
      end

      stream.on(:data) do |d|
        @logger.debug("request data #{d}")
        body += d
      end

      stream.on(:half_close) do
        on_half_close(stream, head, body)
      end
    end

    def on_half_close(stream, head, body)
      message = Zlib::Inflate.inflate(body)
      code, res = @handler.call(head, message)
      do_response(stream, code, res.class.encode(res))
    end

    def do_response(stream, code, body)
      @logger.info('sending response')

      head = { ':status' => '200',
               'grpc-encoding' => 'gzip',
               'grpc-status' => code.to_s,
               'content-type' => 'application/grpc+proto' }

      stream.headers(head, end_stream: false)
      stream.data(Zlib::Deflate.deflate(body))
    end

    def connect
      @logger.info("creating socket server on #{@host}:#{@port}")
      @server = tcp_server
    end

    def tcp_server
      srv = TCPServer.new(@host, @port)
      return srv unless @secure

      if @secure && (!@tls_cert || !@tls_key)
        raise ArgumentError, 'secure option selected, but TLS certificate or key not specified'
      end

      ctx = OpenSSL::SSL::SSLContext.new
      ctx.cert = OpenSSL::X509::Certificate.new(@tls_cert)
      ctx.key = OpenSSL::PKey::RSA.new(@tls_key)
      ctx.ssl_version = :TLSv1_2
      ctx.options = OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options]
      ctx.ciphers = OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:ciphers]

      ctx.alpn_protocols = [ALPN_DRAFT]

      ctx.alpn_select_cb = lambda do |protocols|
        raise "Protocol #{ALPN_DRAFT} is required" if protocols.index(ALPN_DRAFT).nil?
        ALPN_DRAFT
      end

      ctx.ecdh_curves = 'prime256v1'

      OpenSSL::SSL::SSLServer.new(srv, ctx)
    end
  end
end
