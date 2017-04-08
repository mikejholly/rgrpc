# frozen_string_literal: true
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'grpc/version'

Gem::Specification.new do |s|
  s.name = 'rgrpc'
  s.version = RGRPC::VERSION
  s.authors = ['Mike Holly']
  s.email = ['mikejholly@gmail.com']
  s.homepage = 'https://github.com/mikejholly/rgrpc'
  s.summary = 'Pure Ruby gRPC library'
  s.files = Dir['lib/**/*']
  s.test_files = Dir['spec/**/*']
  s.add_dependency 'google-protobuf', '~> 3.2'
  s.add_dependency 'http-2', '~> 0.8.3'
  s.add_development_dependency 'pry-byebug'
end
