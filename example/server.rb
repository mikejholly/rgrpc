# frozen_string_literal: true

require_relative '../lib/rgrpc'

srv = RGrpc::Server.new(host: 'localhost', port: 8080)
srv.start
