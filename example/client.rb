# frozen_string_literal: true

require_relative '../lib/rgrpc'
require_relative 'service_pb'

start = Time.now

cl = RGRPC::Client.new('localhost', 8080)

puts "connect: #{Time.now - start}"

start = Time.now

future = cl.rpc('foo.service/Search',
                FooRequest.new(name: 'foo'),
                RGRPC::Coder.new(FooRequest, FooResponse))

puts "HIHIH"

resp = future.value

cl.close

puts "req: #{Time.now - start}"

puts resp.inspect
