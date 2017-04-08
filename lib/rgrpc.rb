# frozen_string_literal: true

require_relative './rgrpc/server'
require_relative './rgrpc/client'
require_relative './rgrpc/codes'

module RGRPC
  ALPN_DRAFT = 'h2'
  VERSION = '0.1.0'
end
