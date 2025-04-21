local MODE = {
    CLIENT = 0,
    SERVER = 1
}

local mode = nil

for _, arg in ipairs(arg) do
    if arg == "--server" then
        mode = MODE.SERVER
    elseif arg == "--client" then
        mode = MODE.CLIENT
    end
end

if not mode then
    mode = MODE.CLIENT
end

if mode == MODE.SERVER then
    print("Run in server mode")
    require 'server'
elseif mode == MODE.CLIENT then
    print("Run in client mode")
    require 'client'
end
