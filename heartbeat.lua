require 'lovr.filesystem' -- To get `require` work properly
local http = require 'http'
local lovr = {
    thread = require 'lovr.thread',
    timer = require 'lovr.timer',
}

local observer_address = 'http://127.0.0.1/hearbeat'

local counter = 0
while true do
    local status, data = http.request('https://zombo.com')

    print('welcome #' .. counter)
    print(status)
    print(data)
    counter = counter + 1
    lovr.timer.sleep(1)
end
