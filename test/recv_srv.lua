local socket   = require "socket"
local srv  = assert(socket.bind('*', 8041))
local sock = assert(srv:accept())

local len = 0
while true do
  local msg, err, post = sock:receive()
  len = len + #(msg or post)
  if err and err ~= 'timeout' then 
    if err ~= 'closed' then
      print("!!!error:", err)
    end
    break
  end
end

print("recived:", len)

sock:close()
srv:close()
