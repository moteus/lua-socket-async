local socket = require "socket"
local timer  = require "async_socket.timer"

local DEBUG = false
local function trace(...)
   if DEBUG then print(...) end
end

--- 
-- все задержки в мс

local function async_tcp_connect(sock, host, port, timeout, defer_hook, defer_interval)
  local ok, err = sock:connect(host, port)
  if ok then return ok
  elseif err == "timeout" then
    defer_interval = defer_interval and (defer_interval / 1000) or 0
    local cnnt = {sock}
    local rtimer 
    if timeout then
      rtimer = timer:new()
      rtimer:set_interval(timeout)
      rtimer:start()
    end
    while true do
      local r,s,err = socket.select(cnnt, cnnt, defer_interval)
      if s[1] or r[1] then return s[1] or r[1] end
      if err == 'timeout' then
        if timeout and rtimer:rest() == 0 then
           return nil, 'timeout'
        end
        local err = sock:getoption("error")
        if err then return nil, err end
        if defer_hook() == 'break' then return nil, 'break' end
      end
    end
  end
end

local function async_tcp_receive(sock, spec, timeout, defer_hook)
  spec = spec or '*l'
  local rtimer 
  if timeout then
    rtimer = timer:new()
    rtimer:set_interval(timeout)
    rtimer:start()
  end
  local prefix = ''
  while true do
    local data, err, rest = sock:receive(spec, prefix)
    if not data then prefix = rest end
    if data then return data
    elseif err == "timeout" then 
      if timeout and rtimer:rest() == 0 then
        return nil, 'timeout', prefix
      end
      if defer_hook() == 'break' then return nil, 'break', prefix end
    else 
      return nil, err, prefix
    end
  end
end

local function async_tcp_send(sock, msg, i, j, timeout, defer_hook)
  i, j = i or 1, j or #msg
  local rtimer
  if timeout then
    rtimer = timer:new()
    rtimer:set_interval(timeout)
    rtimer:start()
  end
  while true do
    local ok, err, last_i = sock:send(msg,i,j)
    if last_i then assert(
      (last_i >= i and last_i <= j)
      or (last_i == i - 1)
    )
    else assert(ok == j) end
    if ok then return ok
    elseif err ~= "timeout" then 
      return nil, err, j
    else 
      if timeout and rtimer:rest() == 0 then
        return nil, 'timeout', last_i
      end
      i = last_i + 1
      if defer_hook() == 'break' then return nil, 'break', i end
    end
  end
end

local function async_udp_receive(sock, method, size, timeout, defer_hook)
  local rtimer 
  if timeout then
     rtimer = timer:new()
     rtimer:set_interval(timeout)
     rtimer:start()
  end

  while true do
    local ok, err, param = sock[method](sock, size)
    if ok then
      if err then return ok, err, param end
      return ok
    end
    if err ~= 'timeout' then return nil, err end
    if timeout and rtimer:rest() == 0 then
      return nil, 'timeout'
    end
    if defer_hook() == 'break' then return nil, 'break' end
  end
end

local function async_udp_send(sock, method, msg, timeout, defer_hook, ...)
  -- In UDP, the send method never blocks and the only way it can fail is if the 
  -- underlying transport layer refuses to send a message to the 
  -- specified address (i.e. no interface accepts the address). 
  return sock[method](sock, msg, ...)
end

local TIMEOUT_MSEC = 1000
local TIMEOUT_SEC = 1

--- 
-- все задержки в сек

----------------------------------------------
local BASE_TRANSPORT = {} do
BASE_TRANSPORT.__index = BASE_TRANSPORT

function BASE_TRANSPORT:new(idle_hook)
  local t = setmetatable({
    user_data = nil;
    private_ = {
      idle         = idle_hook;
      timeout      = idle_hook and 0 or nil;
      local_param  = {};
      remote_param = {};
      connected    = nil;
    }
  }, self)
  return t
end

function BASE_TRANSPORT:close()
  if self.private_.cnn then
    self.private_.cnn:close()
    self.private_.cnn = nil
    self.private_.connected = nil
  end
end

function BASE_TRANSPORT:is_closed()
  return self.private_.cnn == nil
end

function BASE_TRANSPORT:is_connected()
  return self.private_.connected == true
end

function BASE_TRANSPORT:idle() return self.private_.idle() end

function BASE_TRANSPORT:is_async() return self.private_.idle ~= nil end

local function get_host_port(self, fn)
  if not self.private_.cnn then  return nil, 'closed' end
  local ok, err = self.private_.cnn[fn](self.private_.cnn)
  if not ok then
    if err == 'closed' then self:close() end
    return nil,err
  end
  return ok, err
end

function BASE_TRANSPORT:local_host()
  if self:is_closed() then return nil, 'closed' end
  if not self.private_.local_param.host then
    local host, port = get_host_port(self,"getsockname")
    if not host then
      return nil,port
    end
    self.private_.local_param.host = host;
    self.private_.local_param.port = port;
  end
  return self.private_.local_param.host 
end

function BASE_TRANSPORT:local_port()
  if self:is_closed() then return nil, 'closed' end
  if not self.private_.local_param.host then
    local host, port = get_host_port(self,"getsockname")
    if not host then
      return nil,port
    end
    self.private_.local_param.host = host;
    self.private_.local_param.port = port;
  end
  return self.private_.local_param.port 
end

function BASE_TRANSPORT:remote_host()
  if self:is_closed() then return nil, 'closed' end
  if not self.private_.remote_param.host then
    local host, port = get_host_port(self,"getpeername")
    if not host then
      return nil,port
    end
    self.private_.remote_param.host = host;
    self.private_.remote_param.port = port;
  end
  return self.private_.remote_param.host 
end

function BASE_TRANSPORT:remote_port()
  if self:is_closed() then return nil, 'closed' end
  if not self.private_.remote_param.host then
    local host, port = get_host_port(self,"getpeername")
    if not host then
      return nil,port
    end
    self.private_.remote_param.host = host;
    self.private_.remote_param.port = port;
  end
  return self.private_.remote_param.port 
end

function BASE_TRANSPORT:set_timeout(value)
  if self:is_closed() then return nil, 'closed' end

  -- этот timeout используется в асинхронном режиме.
  -- Он означает как часто вызывать idle_hook.
  -- в синхронном он перезаписывается при каждой операции В/В
  if value then value = value * TIMEOUT_SEC end

  local ok,err = self.private_.cnn:settimeout(value)
  if not ok then
    self:close()
    return nil,err
  end
  self.private_.timeout = value
  return value
end

function BASE_TRANSPORT:timeout()
  if self.private_.timeout then 
    return self.private_.timeout / TIMEOUT_SEC 
  end
end

function BASE_TRANSPORT:on_closed()
  return self:disconnect()
end

end
----------------------------------------------

----------------------------------------------
local TCP_TRANSPORT = setmetatable({}, BASE_TRANSPORT) do
TCP_TRANSPORT.__index = TCP_TRANSPORT

local function init_socket(self)
  if self.private_.cnn then return self.private_.cnn end
  local cnn, err = socket.tcp()
  if not cnn then return nil, err end
  if self:is_async() then 
    local ok, err = cnn:settimeout(self.private_.timeout) 
    if not ok then
      cnn:close()
      return nil, err
    end
  end
  self.private_.cnn = cnn
  return cnn
end

function TCP_TRANSPORT:bind(host,port)
  local cnn, err = init_socket(self)
  if not cnn then return nil,err end

  local ok,err = cnn:bind(host or "*", port)
  if not ok then
    self:close()
    return nil,err
  end

  self.private_.local_param.host = nil;
  self.private_.local_param.port = nil;

  return true;
end

function TCP_TRANSPORT:connect(timeout, host, port)
  local cnn, err = init_socket(self)
  if not cnn then return nil,err end

  local ok, err
  if self:is_async() then
    ok, err = async_tcp_connect(cnn, host, port, timeout, self.private_.idle)
  else
    cnn:settimeout(timeout)
    ok,err  = cnn:connect(host, port)
  end
  if not ok then 
    if err == "closed" then self:on_closed() end
    return ok,err
  end

  self.private_.remote_param.host = nil;
  self.private_.remote_param.port = nil;

  return true
end

function TCP_TRANSPORT:disconnect()
  return self:close()
end

function TCP_TRANSPORT:recv_async_impl(timeout, spec)
  if timeout then timeout = timeout * TIMEOUT_MSEC end
  local ok, err, msg = async_tcp_receive(
    self.private_.cnn, 
    spec, timeout, 
    self.private_.idle
  )
  if err == "closed" then self:on_closed() end
  return ok, err, msg
end

function TCP_TRANSPORT:recv_sync_impl(timeout, spec)
  if timeout then timeout = timeout * TIMEOUT_SEC end
  local ok, err = self.private_.cnn:settimeout(timeout)
  if not ok then return nil, err end
  ok, err, data = self.private_.cnn:receive(spec)
  if ok then return ok end
  if err == 'closed' then self:close() end
  return nil, err, data
end

function TCP_TRANSPORT:send_async_impl(timeout, msg, i, j)
  if timeout then timeout = timeout * TIMEOUT_MSEC end
  local ok, err, n = async_tcp_send(
    self.private_.cnn, 
    msg, i, j, timeout, 
    self.private_.idle
  )
  if err == "closed" then self:on_closed() end
  return ok, err, n
end

function TCP_TRANSPORT:send_sync_impl(timeout, msg, i, j)
  if timeout then timeout = timeout * TIMEOUT_SEC end
  local ok, err = self.private_.cnn:settimeout(timeout)
  if not ok then return nil, err end
  ok, err = self.private_.cnn:send(msg, i, j)
  if ok then return ok end
  if err == "closed" then self:on_closed() end
  return nil, err
end

function TCP_TRANSPORT:send(...)
  if self:is_closed() then return nil, 'closed' end
  if self:is_async() then return self:send_async_impl(...) end
  return self:send_sync_impl(...) 
end

function TCP_TRANSPORT:recv(...)
  if self:is_closed() then return nil, 'closed' end
  if self:is_async() then return self:recv_async_impl(...) end
  return self:recv_sync_impl(...) 
end

end
----------------------------------------------

----------------------------------------------
local UDP_TRANSPORT = setmetatable({}, BASE_TRANSPORT) do
UDP_TRANSPORT.__index = UDP_TRANSPORT

local function init_socket(self)
  if self.private_.cnn then return self.private_.cnn end
  local cnn, err = socket.udp()
  if not cnn then return nil, err end
  if self:is_async() then 
    local ok, err = cnn:settimeout(self.private_.timeout)
    if not ok then 
      cnn:close()
      return nil, err
    end
  end
  self.private_.cnn = cnn
  return cnn
end

function UDP_TRANSPORT:bind(host,port)
  if self:is_connected() then
    local ok, err = self:disconnect()
    if not ok then return nil, err end
  end

  local cnn, err = init_socket(self)
  if not cnn then return nil,err end

  self.private_.cnn = cnn

  local ok,err = cnn:setsockname(host or "*", port or 0)
  if not ok then
    self:close()
    return nil,err
  end

  if self:is_async() then
    ok,err = cnn:settimeout(0)
    if not ok then
      self:close()
      return nil,err
    end
  end

  return true;
end

function UDP_TRANSPORT:connect(host,port)
  if self:is_connected() then
    local ok, err = self:disconnect()
    if not ok then return nil, err end
  end

  local cnn, err = init_socket(self)
  if not cnn then return nil,err end

  local ok,err = self.private_.cnn:setpeername(host, port)
  if not ok then return nil,err end
  self.private_.remote_param.host = nil
  self.private_.remote_param.port = nil
  self.private_.connected = true
  return true
end

function UDP_TRANSPORT:disconnect()
  local ok,err = self.private_.cnn:setpeername('*')
  if not ok then return nil,err end
  self.private_.remote_param.host = nil
  self.private_.remote_param.port = nil
  self.private_.connected = nil;
  return true
end

function UDP_TRANSPORT:recv_async_impl(recv, timeout, size)
  if timeout then timeout = timeout * TIMEOUT_MSEC end
  local ok, err, param = async_udp_receive(self.private_.cnn, recv, size, timeout, self.private_.idle)
  if ok then
    if err then return ok, err, param end
    return ok
  end
  if err == "closed" then self:on_closed() end
  return nil,err
end

function UDP_TRANSPORT:recv_sync_impl(recv, timeout, ...)
  if timeout then timeout = timeout * TIMEOUT_SEC end
  local ok, err = self.private_.cnn:settimeout(timeout)
  if not ok then return nil, err end
  local param
  ok, err, param = self.private_.cnn[recv](self.private_.cnn, ...)
  if ok then
    if err then return ok, err, param end
    return ok
  end
  if err == "closed" then self:on_closed() end
  return nil, err
end

function UDP_TRANSPORT:recv_impl(...)
  if self:is_closed() then return nil, 'closed' end
  if self:is_async() then return self:recv_async_impl(...) end
  return self:recv_sync_impl(...) 
end

function UDP_TRANSPORT:send_sync_impl(send, timeout, msg, ...)
  local ok, err = self.private_.cnn[send](self.private_.cnn, msg, ...)
  if ok then return ok end
  if err == "closed" then self:on_closed() end
  return nil, err
end

function UDP_TRANSPORT:send_async_impl(send, timeout, msg, ...)
  if timeout then timeout = timeout * TIMEOUT_MSEC end
  local ok, err = async_udp_send(self.private_.cnn, send, msg, timeout, self.private_.idle, ...)
  if ok then return ok end
  if err == "closed" then self:on_closed() end
  return nil,err
end

function UDP_TRANSPORT:send_impl(...)
  if self:is_closed() then return nil, 'closed' end
  if self:is_async() then return self:send_async_impl(...) end
  return self:send_sync_impl(...) 
end

function UDP_TRANSPORT:send(...) return self:send_impl("send", ...) end
function UDP_TRANSPORT:sendto(...) return self:send_impl("sendto", ...) end

function UDP_TRANSPORT:recv(...) return self:recv_impl("receive", ...) end
function UDP_TRANSPORT:recvfrom(...) return self:recv_impl("receivefrom", ...) end

end
----------------------------------------------

local _M = {}

_M.tcp_client = function(...) return TCP_TRANSPORT:new(...) end

_M.udp_client = function(...) return UDP_TRANSPORT:new(...) end

_M.async_tcp_connect = async_tcp_connect

_M.async_tcp_receive = async_tcp_receive

_M.async_tcp_send    = async_tcp_send

_M.async_udp_receive = async_udp_receive

_M.async_udp_send    = async_udp_send

return _M
