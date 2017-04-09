# Ruby gRPC

A gRPC client in pure Ruby.

## Server

A new server can be constructed using a handler. The handler needs only to
implement a `call` method. It will recieve the gRPC headers along with the
decoded protobuf message specified by your Protobuf RPC definition.

```ruby
require_relative 'rgrpc'
require_relative 'service_pb' # Your Protobuf definition

#
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

# Create the server and specify the RPC handler
srv = RGRPC::Server.new(handler: Service.new,
                        host: 'localhost',
                        port: 8080,
                        secure: true,
                        tls_cert: File.read('/tmp/test.crt'),
                        tls_key: File.read('/tmp/test.key'))

# Listen for connections
srv.listen
```

The server will pass a request to the handler. Implement your method similar to the
example above.

## Client

The client performs an HTTP2 request and sends the Protobuf message to a gRPC server.


```ruby
require_relative 'rgrpc'
require_relative 'service_pb'

# Create a new client (TLS optional)
cl = RGRPC::Client.new(host: 'localhost',
                       port: 8080,
                       secure: true)

# Perform an RPC call. Specify the method name and request message.
# `returns` takes the expected type of the result.
resp = cl.rpc('foo.service/Search',
              FooRequest.new(name: 'foo'),
              returns: FooResponse)

# Do something with the result
puts resp.inspect
```
