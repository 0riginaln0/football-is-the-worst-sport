local enet = require 'enet'
local buf = require 'string.buffer'
local protocol = require 'protocol'
local dbg = require 'lib.debugger'
local phywire = require 'lib.phywire'
phywire.options.show_shapes = true     -- draw collider shapes (on by default)
phywire.options.show_velocities = true -- vector showing direction and magnitude of collider linear velocity
phywire.options.show_angulars = true   -- gizmo displaying the collider's angular velocity
phywire.options.show_joints = true     -- show joints between colliders
phywire.options.show_contacts = true   -- show collision contacts (quite inefficient, triples the needed collision computations)
phywire.options.wireframe = true
local pl = require 'player'

local server = {
    address = 'localhost:6750',
    max_peers = 32,
    channel_count = 3, -- 0 for "unsequenced", 1 for "unreliable", 2 for "reliable"
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

local state = {
    world = nil,
    CONST_DT = 0.015, -- my constant dt, aka "the timestep"
    accumulator = 0,  -- accumulator of time to simulate
    ground = nil
}


local function getFreeId(players)
    local free_id = nil
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
    server.host = enet.host_create(server.address, server.max_peers, server.channel_count)

    -- Create world
    lovr.graphics.setBackgroundColor(0x87ceeb)
    state.world = lovr.physics.newWorld({ tags = { "ground", "ball", "ball-area", "player" } })
    state.world:disableCollisionBetween("ball-area", "ball")
    state.world:disableCollisionBetween("ball-area", "ground")
    state.world:disableCollisionBetween("ball-area", "player")

    state.ground = state.world:newBoxCollider(vec3(0, -2, 0), vec3(90, 4, 120))
    state.ground:setFriction(0.2)
    state.ground:setKinematic(true)
    state.ground:setTag("ground")

    -- Create players
    for index, slot in ipairs(players) do
        slot.player = pl.new()
    end
end

local function handleAuthEvent(peer)
    local free_id = getFreeId(players)

    peer:send(buf.encode({ type = protocol.stc.id, id = free_id }), protocol.channel.reliable, "reliable")

    players[free_id].status = "occupied"
    players[free_id].peer = peer
end

local function handleInputEvent(msg)
    players[msg.id].input = msg
end
local function handleIncomingEvents()
    local event = server.host:service(3) -- Consider changing timeout to 0
    local count, limit = 0, 50           -- Handle maximum of 50 events per frame
    while event and count < limit do
        if event.type == "receive" then
            local msg = buf.decode(event.data)
            if msg then
                if msg.type == protocol.cts.auth then
                    handleAuthEvent(event.peer)
                elseif msg.type == protocol.cts.input then
                    handleInputEvent(msg)
                end
            end
        elseif event.type == "connect" then
            --register player
            print("Connected: ", event.peer)
        elseif event.type == "disconnect" then
            --unregister player
            print("Disconnected: ", event.peer)
            local id_to_make_free
            for index, value in ipairs(players) do
                if tostring(value.peer) == tostring(event.peer) then
                    id_to_make_free = index
                    break
                end
            end
            players[id_to_make_free].status = "free"
            players[id_to_make_free].input = {}
            players[id_to_make_free].peer = nil
        end
        event = server.host:check_events()
        count = count + 1
    end
end

local function sendUpdatedSnapshot(snapshot)
    -- -- Consider iterating over array of players
    -- for i = 1, server.max_peers do
    --     local peer = server.host:get_peer(i)
    --     if peer:state() == 'connected' then
    --         --peer:send("New frame: " .. tostring(server.frame))
    --     end
    -- end



    for index, player in ipairs(players) do
        if player.status == "occupied" and player.peer then
            player.peer:send(
                buf.encode({ type = protocol.stc.update, snapshot = snapshot }),
                protocol.channel.unsequenced,
                "unsequenced"
            )
        end
    end
end

function lovr.update(dt)
    server.frame = server.frame + 1

    handleIncomingEvents()

    -- Run a physical simulation step
    -- Update all objects

    for index, player in ipairs(players) do
        if player.status == "occupied" and player.peer and player.input then
            if player.input.lmb_pressed then
                local x, y, z = state.ground:getPosition()
                state.ground:setPosition(x, y + 0.1, z)
            end
            if player.input.rmb_pressed then
                local x, y, z = state.ground:getPosition()
                state.ground:setPosition(x, y - 0.1, z)
            end
        end
    end

    -- Decide if any client needs a world update and take a snapshot of the current world state
    -- if necessary
    local x, y, z = state.ground:getPosition()
    local snapshot = {
        ground = {
            x = x, y = y, z = z
        }
    }
    sendUpdatedSnapshot(snapshot)
end

function lovr.draw(pass)
    pass:setColor(0x121212)
    pass:plane(0, 0.01, 0, 90, 120, -math.pi / 2, 1, 0, 0, 'line', 45, 60)
    phywire.draw(pass, state.world)

    for index, collider in ipairs(state.world:getColliders()) do
        local tag = collider:getTag()
        if tag == "ground" then
            local shape = collider:getShapes()[1]
            pass:setColor(0.1, 0.5, 0.1)
            local x, y, z, angle, ax, ay, az = collider:getPose()
            local sx, sy, sz = shape:getDimensions()
            pass:box(x, y, z, sx, sy, sz, angle, ax, ay, az)
        end
    end
end
