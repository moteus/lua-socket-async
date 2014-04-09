package = "luasocket-async"
version = "scm-0"

source = {
  url = "https://github.com/moteus/lua-socket-async/archive/master.zip",
  dir = "lua-socket-async-master",
}

description = {
  summary = "Async wrapper around LuaSocket",
  homepage = "https://github.com/moteus/lua-socket-async",
  license = "MIT/X11",
}

dependencies = {
  "lua >= 5.1, < 5.3",
  "luasocket",
}

build = {
  copy_directories = {"test"},

  type = "builtin",

  modules = {
    ["async_socket"        ] = "lua/async_socket.lua";
    ["async_socket.timer"  ] = "lua/async_socket/timer.lua";
  },
}


