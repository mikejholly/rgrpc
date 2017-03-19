# frozen_string_literal: true

require_relative '../src/rgrpc'

cl = RGrpc::Client.new(host: 'localhost', port: 8080)
puts cl.send

loop {}
