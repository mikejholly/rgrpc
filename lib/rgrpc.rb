# frozen_string_literal: true

require_relative './rgrpc/server'
require_relative './rgrpc/client'
require_relative './rgrpc/codes'
require_relative './rgrpc/coder'
require_relative './rgrpc/request'
require_relative './rgrpc/response'
require_relative './rgrpc/tcp_socket_builder'
require_relative './rgrpc/secure_socket_builder'

module RGRPC
  ALPN_DRAFT = 'h2'
  VERSION = '0.1.0'
end
