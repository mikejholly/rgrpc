# frozen_string_literal: true

require_relative '../lib/rgrpc'
require_relative 'service_pb'

cl = RGrpc::Client.new(host: 'localhost', port: 8080)
cl.rpc(:Search, FooRequest.new(), returns: FooResponse)
