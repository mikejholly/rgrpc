# frozen_string_literal: true

require_relative '../lib/rgrpc'
require_relative 'service_pb'

class Service
  def call(headers, message)
    case headers[':path']
    when 'foo.service/Search' then handle_search(headers, message)
    end
  end

  private

  def handle_search(_headers, _message)
    res = FooResponse.new(foos: [])
    res.foos << Foo.new(name: 'Mike', id: 1)
    res.foos << Foo.new(name: 'Bill', id: 2)

    [RGRPC::Codes::OK, res]
  end
end

srv = RGRPC::Server.new(handler: Service.new,
                        host: 'localhost',
                        port: 8080,
                        secure: true,
                        tls_cert: File.read('/tmp/test.crt'),
                        tls_key: File.read('/tmp/test.key'))
srv.listen
