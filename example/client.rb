# frozen_string_literal: true

require_relative '../lib/rgrpc'
require_relative 'service_pb'

start = Time.now

cl = RGRPC::Client.new('localhost', 8080)
cl.connect

puts "connect: #{Time.now - start}"

start = Time.now

code, message = cl.rpc('foo.service/Search',
                       FooRequest.new(name: 'foo'),
                       RGRPC::Coder.new(FooRequest, FooResponse))

puts
puts "req: #{Time.now - start}"
puts "status code: #{code}"
puts "message: #{message.inspect}"
puts

cl.close
