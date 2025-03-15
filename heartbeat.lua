require 'lovr.filesystem' -- To get `require` work properly
local http = require 'http'
local json = require 'lib.json'
local lovr = {
  thread = require 'lovr.thread',
  timer = require 'lovr.timer',
}

local observer_address = 'http://yourip:yourport/'
local port = 2
local counter = 0
while true do
  local headers = {
    ["Content-Type"] = "application/json",
    ["accept"] = "application/json",
  }
  local info = json.encode { players_count = counter }
  local status, data = http.request(
    observer_address .. "heartbeat?port=" .. port,
    { headers = headers, data = info })

  print('welcome #' .. counter)
  print(status)
  print(data)
  counter = counter + 1
  lovr.timer.sleep(2)
end
