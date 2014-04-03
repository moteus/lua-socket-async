local pop3         = require "pop3"
local async_socket = require "async_socket"

local host = "127.0.0.1"
local port = 110

local user = "test@mail.local"
local pass = "123456"

function create_cnn(idle, idle_timeout, cnn_timeout)
  return function(host, port)
    local cnn = async_socket.tcp_client(idle)
    if idle_timeout then cnn:set_timeout(idle_timeout) end

    local timeout -- io timeout
    local ok, err = cnn:connect(cnn_timeout, host, port)
    if not ok then return nil, err end
    return {
      send        = function (self, ...) return cnn:send(timeout, ...) end;
      receive     = function (self, ...) return cnn:recv(timeout, ...) end;
      close       = function ()          return cnn:close()            end;
      settimeout  = function (self, val) timeout = val                 end;
    }
  end
end

local cnt = 0
local function counter() cnt = cnt + 1 end

local mbox = pop3.new(create_cnn(counter, 10000))

print(mbox:open(host, port, 5000))

print("Open counter:", cnt)

print(mbox:auth(user, pass))

print("Auth counter:", cnt)

for id, msg in mbox:messages() do
  
end

mbox:close()

print("Total counter:", cnt)
