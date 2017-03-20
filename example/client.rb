# frozen_string_literal: true

require_relative '../lib/rgrpc'

cl = RGrpc::Client.new(host: 'localhost', port: 8080)
puts cl.send

loop {}
