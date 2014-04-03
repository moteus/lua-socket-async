local async_socket = require "async_socket"
local timer        = require "timer"

local HOST = arg[1] or '127.0.0.1'

function test_recv()
  print("---- START TEST RECV")
  local cnt = 0
  function counter() cnt = cnt + 1 end

  local cnn = async_socket.tcp_client(counter)
  local ok, err = cnn:connect(nil, HOST, '8042')
  print("CONNECT:",ok, err)
  print("COUNTER:",cnt)
  if not ok then 
    cnn:close()
    return;
  end
  print("---- CONNECT PASSED")

  print("local_host :", cnn:local_host())
  print("local_port :", cnn:local_port())
  print("remote_host:", cnn:remote_host())
  print("remote_port:", cnn:remote_port())

  local pt = timer:new()
  pt:start()
  print("RECV (5 sec):",cnn:recv(5))
  print("RECV (5 sec):",cnn:recv(5))
  print("RECV (5 sec):",cnn:recv(5))
  print("RECV (5 sec):",cnn:recv(5))
  print("RECV (5 sec):",cnn:recv(5))
  print("COUNTER:", cnt)
  print("ELAPSED:", pt:elapsed())
  cnn:close()
  print("---- RECV PASSED")
end

test_recv()
