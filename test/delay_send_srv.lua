local socket = require "socket"
local srv    = assert(socket.bind('*', 8042))
local sock   = assert(srv:accept())
print(sock)
socket.sleep(10)
for i = 1,9 do
  sock:send(tostring(i))
  socket.sleep(1)
end

sock:send(
  string.char(10) .. string.char(13)
)

sock:close()
