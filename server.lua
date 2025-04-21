local enet = require 'enet'

local frame = 0

local server = {
    max_peers = 32,
    host = nil,
    event = nil,
    address = 'localhost:6750'
}

local player_info = {
    status = "connected", -- disconnected
    id = 1,
    peer = nil,
    input = nil,
    last_frame = 0
}

local players_info = {
    -- 30 entries
    -- Red team
    {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {},
    -- Blue team
    {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {},
}

local game_data = 1

function lovr.load()
    print("Starting as server...")
    server_host = enet.host_create(server_address, max_peers)
end

local function serverListen()
    hostevent = server_host:service(0)

    if hostevent then
        print("Server detected message type: " .. hostevent.type)
        if hostevent.type == "connect" then
            print(hostevent.peer, "connected.")
        end
        if hostevent.type == "receive" then
            print("Received message: ", hostevent.data, hostevent.peer)
        end
    end
end

local function sendUpdate()
    for i = 1, max_peers do
        local peer = server_host:get_peer(i)
        if peer:state() == 'connected' then
            game_data = game_data + 1
            peer:send(game_data)
        end
    end
end

function lovr.update(dt)
    frame = frame + 1

    -- Process incoming user commands
    serverListen()

    -- Run a physical simulation step
    -- Update all objects

    -- Decide if any client needs a world update and take a snapshot of the current world state
    -- if necessary
    sendUpdate()
end
