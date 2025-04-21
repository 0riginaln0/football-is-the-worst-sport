local enet = require 'enet'
local buf = require 'string.buffer'
local protocol = require 'protocol'

local server = {
    address = 'localhost:6750',
    max_peers = 32,
    channel_count = 2, -- 1 for "unsequenced", 2 for "reliable"
    host = nil,
    frame = 0,
}

local playerexample = {
    status = "", -- occupied free
    input = {},
    peer = nil
}

local players = {
    -- 30 entries
    { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" },
    { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" },
    { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" },
    { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" },
    { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" },
    { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" },
}

local function getFreeId(players)
    local free_id
    for index, value in ipairs(players) do
        if value.status == "free" then
            free_id = index
            break
        end
    end
    return free_id
end

function lovr.load()
    print("Starting as server...")
    server.host = enet.host_create(server.address, server.max_peers)
end

local function handleIncomingEvents()
    local event = server.host:service(3) -- Consider changing timeout to 0
    local count, limit = 0, 50           -- Handle maximum of 50 events per frame
    while event and count < limit do
        if event.type == "receive" then
            local msg = buf.decode(event.data)

            if msg and msg.type == protocol.cts.auth then
                local free_id = getFreeId(players)
                event.peer:send(buf.encode({ type = protocol.cts.input, id = free_id }))
                players[free_id].status = "occupied"
                players[free_id].peer = tostring(event.peer)
            elseif msg and msg.type == protocol.cts.input then
                players[msg.id].input = msg
                print(msg.mouse_x)
            end
        elseif event.type == "connect" then
            --register player
            print("Connected: ", event.peer)
        elseif event.type == "disconnect" then
            --unregister player
            print("Disconnected: ", event.peer)
            local id_to_make_free
            for index, value in ipairs(players) do
                if value.peer == tostring(event.peer) then
                    id_to_make_free = index
                    break
                end
            end
            players[id_to_make_free].status = "free"
        end
        event = server.host:check_events()
        count = count + 1
    end
end

local function sendUpdatedSnapshot()
    -- Consider iterating over array of players
    for i = 1, server.max_peers do
        local peer = server.host:get_peer(i)
        if peer:state() == 'connected' then
            --peer:send("New frame: " .. tostring(server.frame))
        end
    end
end

function lovr.update(dt)
    server.frame = server.frame + 1

    handleIncomingEvents()

    -- Run a physical simulation step
    -- Update all objects

    -- Decide if any client needs a world update and take a snapshot of the current world state
    -- if necessary
    sendUpdatedSnapshot()
end
