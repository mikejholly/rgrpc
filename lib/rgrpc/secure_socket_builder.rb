# frozen_string_literal: true

require 'socket'

module RGRPC
  # Creates a secure TCP socket
  class SecureSocketBuilder < TCPSocketBuilder
    def initialize(host, port, tls_config)
      @host = host
      @port = port
      @tls_config = tls_config
    end

    def build
      tcp = TCPSocket.new(@host, @port)
      ctx = create_ssl_context

      sock = OpenSSL::SSL::SSLSocket.new(tcp, ctx)
      sock.sync_close = true
      sock.hostname = @host
      sock.connect

      if sock.alpn_protocol != ALPN_DRAFT
        raise "Failed to negotiate #{ALPN_DRAFT} via ALPN"
      end

      sock
    end

    private

    def create_ssl_context
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE
      ctx.ssl_version = :TLSv1_2
      ctx.client_ca = @tls_config.ca if @tls_config.ca

      if @tls_config.cert && @tls_config.key
        ctx.cert = OpenSSL::X509::Certificate.new(@tls_config.cert)
        ctx.key = OpenSSL::PKey::RSA(@tls_config.key)
      end

      ctx.alpn_protocols = [ALPN_DRAFT]
      ctx.alpn_select_cb = lambda do |protocols|
        ALPN_DRAFT if protocols.include?(ALPN_DRAFT)
      end

      ctx
    end
  end
end
