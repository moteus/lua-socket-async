lua-socket-async
================

Asyncronus wrapper around LuaSocket library

##Usage

```
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
