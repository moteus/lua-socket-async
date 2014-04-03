local async_socket = require "async_socket"
local timer        = require "timer"

local HOST = arg[1] or '127.0.0.1'

function test_send()
  print("---- START TEST SEND")

  local cnt = 0
  function counter() cnt = cnt + 1 end

  local cnn = async_socket.tcp_client(counter)
  local ok, err = cnn:connect(nil, HOST, '8041')
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
  print("SEND:", cnn:send(1.5, ("hello"):rep(50000)))
  print("COUNTER:", cnt)
  print("ELAPSED:", pt:elapsed())
  cnn:close()
  print("---- SEND PASSED")
end

test_send()