local IS_WINDOWS = (package.config:sub(1,1) == '\\')

local socket   = require "socket"

local function s_sleep(ms) return socket.sleep(ms / 1000) end

local function s_clock()   return socket.gettime() * 1000 end

local s_tick, s_tick_elapsed

if not s_tick then
  local ok, winutil = pcall(require, "winutil")
  if ok then
    s_tick         = winutil.get_tick_count
    s_tick_elapsed = winutil.get_tick_elapsed
  end
end

if not s_tick and IS_WINDOWS then
  local ok, ffi = pcall(require, "ffi")
  if ok then
    ffi.cdef"uint32_t __stdcall GetTickCount();"
    local GetTickCount = ffi.C.GetTickCount
    local MAX_DWORD = 0xFFFFFFFF

    s_tick = GetTickCount
    s_tick_elapsed = function(t)
      local cur = s_tick()
      if cur >= t then return cur - t end
      return cur + (MAX_DWORD - t)
    end
  end
end

if not s_tick and IS_WINDOWS then
  local ok, alien =  pcall(require, "alien")
  if ok then
    local kernel32     = assert(alien.load("kernel32.dll"))
    local GetTickCount = assert(kernel32.GetTickCount)
    GetTickCount:types{abi="stdcall", ret = "uint"}
    local MAX_DWORD = 0xFFFFFFFF

    s_tick = GetTickCount
    s_tick_elapsed = function(t)
      local cur = s_tick()
      if cur >= t then return cur - t end
      return cur + (MAX_DWORD - t)
    end
  end
end

if not s_tick then
  s_tick = s_clock
  function s_tick_elapsed(t)  return s_clock() - t end
end

---
-- таймеры 
--  сработать в определенное время
--  сработать через определенное время
--  узнать сколько времени прошло

local timer = {}

function timer:new(...)
  local t = setmetatable({},{__index = self})
  return t:init(...)
end

function timer:init()
  self.private_ = {}
  return self
end

---
-- Устанавливает абсолютное время для срабатывания
function timer:set_time(tm)
  self.private_.time     = tm
  self.private_.interval = nil
  return self
end

---
-- Устанавливает переод через который необходимо сработать
function timer:set_interval(interval)
  assert(interval == nil or type(interval) == 'number')
  self.private_.time     = nil
  self.private_.interval = interval
  return self
end

function timer:reset()
  self.private_.start_tick = nil
  self.private_.time       = nil
  self.private_.interval   = nil
end

function timer:time()
  return self.private_.time
end

function timer:interval()
  return self.private_.interval
end

---
-- Запускает отсчет
function timer:start()
  self.private_.start_tick    = s_tick()
  self.private_.fire_time     = self.private_.time
  self.private_.fire_interval = self.private_.interval
  return self
end

---
-- Возвращает признак запущен ли таймер
function timer:started()
  return self.private_.start_tick and true or false
end

---
-- Останавливает таймер
function timer:stop()
  local elapsed = self:elapsed()
  self.private_.start_tick    = nil
  self.private_.fire_time     = nil
  self.private_.fire_interval = nil
  return elapsed
end

---
--
function timer:restart()
  local result = self:stop()
  self:start()
  return result;
end

---
-- Возвращает время от старта
function timer:elapsed()
  assert(self:started())
  return s_tick_elapsed(self.private_.start_tick)
end

---
-- Возвращает время до момента окончания
-- если перед стартом не были вызваны set_time или set_interval
-- будет всегда возвращатся 0
-- таймер остается в активном состоянии
function timer:rest()
  assert(self:started())
  local interval
  if self.private_.fire_time then         interval = self.private_.fire_time     - s_clock()
  elseif self.private_.fire_interval then interval = self.private_.fire_interval - self:elapsed()
  else return 0 end

  if interval <= 0 then 
    self.private_.fire_time     = nil
    self.private_.fire_interval = nil
    interval = 0
  end
  return interval
end

local M = {}

M.sleep        = s_sleep
M.clock        = s_clock
M.tick_count   = s_tick
M.tick_elapsed = s_tick_elapsed

M.new = function (...) return timer:new(...) end

return M