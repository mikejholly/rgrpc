# frozen_string_literal: true

require_relative '../lib/rgrpc'
require_relative 'service_pb'

start = Time.now

cl = RGRPC::Client.new(host: 'localhost',
                       port: 8080,
                       secure: false)

puts "connect: #{Time.now - start}"

start = Time.now
resp = cl.rpc('foo.service/Search',
              FooRequest.new(name: 'foo'),
              returns: FooResponse)

puts "req: #{Time.now - start}"

puts resp.inspect
