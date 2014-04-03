lua-socket-async
================

Asyncronus wrapper around LuaSocket library

The idea is taken from [lua-memcached](https://github.com/silentbicycle/lua-memcached)

#API

## tcp_client(idle)

Create tcp client socket.

## udp_client(idle)

Create udp client socket.

# Common Socket methods

## local_host()

## local_port()

## remote_host()

## remote_port()

## set_timeout(value)

## timeout()

# TCP Socket methods

## connect(timeout, host, port)

Connect the socket to the specified host/port.

## disconnect()

Disconnect the socket.

## bind(host, port)

Binds the socket to the specified host/port.

## send(timeout, msg [,i [,j]])

## recv(timeout [,pattern])

# UDP Socket methods

## connect(host, port)

Set peername for socket.

## disconnect()

Clear peername on the socket.

## bind(host, port)

Set sockname on the socket.

## send(timeout, msg [,i [,j]])

## recv(timeout [,size])

## sendto(timeout, msg, host, port)

## recvfrom(timeout [,size])

##Usage

``` Lua
local async_socket  = require "async_socket"

-- 
local cnt = 0
function idle() cnt = cnt + 1 end

local cnn = async_socket.tcp_client(idle)

local ok = assert(cnn:connect(nil, HOST, PORT))

print("CONNECT:",cnt)

cnn:send(5, MESSAGE)

print("SEND:",cnt)

MESSAGE = cnn:recv(5)

print("RECV:", cnt)

cnn:close()
```

Using async socket with [lua-pop3](https://github.com/moteus/lua-pop3) library - [async_pop3.lua](/examples/async_pop3.lua)
