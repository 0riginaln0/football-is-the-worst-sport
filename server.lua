local enet = require "enet"
local buf = require "string.buffer"
local protocol = require "protocol"
local dbg = require "lib.debugger"
local phywire = require "lib.phywire"
phywire.options.show_shapes = false    -- draw collider shapes (on by default)
phywire.options.show_velocities = true -- vector showing direction and magnitude of collider linear velocity
phywire.options.show_angulars = true   -- gizmo displaying the collider's angular velocity
phywire.options.show_joints = true     -- show joints between colliders
phywire.options.show_contacts = true   -- show collision contacts (quite inefficient, triples the needed collision computations)
phywire.options.wireframe = true
local b = require "ball"

local p = require "player"

local constants = {
    K = 0.1
}

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
    peer = nil,
    player = nil
}

local ballexample = {
    model = nil,
    collider = nil,
    area = nil,
}

local state = {
    world = nil,
    CONST_DT = 0.015, -- my constant dt, aka "the timestep"
    accumulator = 0,  -- accumulator of time to simulate
    ground = nil,
    players_slots = {
        -- 30 entries
        { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" },
        { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" },
        { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" },
        { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" },
        { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" },
        { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" },
    },
    balls = {
        -- 22 entries
    }
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
    for index, slot in ipairs(state.players_slots) do
        slot.player = p.createPlayer(state.world, 40, 0, -30 + index * 2)
    end

    -- Create balls
    for i = 1, 22, 1 do
        state.balls[i] = b.createBall(state.world, i, 23 + math.random(1, 4), 0)
    end
end

local function handleAuthEvent(peer)
    local free_id = getFreeId(state.players_slots)

    peer:send(buf.encode({ type = protocol.stc.id, id = free_id }), protocol.channel.reliable, "reliable")

    state.players_slots[free_id].status = "occupied"
    state.players_slots[free_id].peer = peer
end

local function handleInputEvent(msg)
    state.players_slots[msg.id].input = msg
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
            for index, value in ipairs(state.players_slots) do
                if tostring(value.peer) == tostring(event.peer) then
                    id_to_make_free = index
                    break
                end
            end
            state.players_slots[id_to_make_free].status = "free"
            state.players_slots[id_to_make_free].input = {}
            state.players_slots[id_to_make_free].peer = nil
        end
        event = server.host:check_events()
        count = count + 1
    end
end

local function sendUpdatedSnapshot(snapshot)
    for index, player in ipairs(state.players_slots) do
        if player.status == "occupied" and player.peer then
            player.peer:send(
                buf.encode({ type = protocol.stc.update, snapshot = snapshot }),
                protocol.channel.unsequenced,
                "unsequenced"
            )
        end
    end
end



local function updateBallPhysics(balls)
    for id, ball in ipairs(balls) do
        -- Apply the Magnus force
        local magnusX, magnusY, magnusZ = b.calculateMagnusForce(ball.collider, constants.K)
        ball.collider:applyForce(magnusX, magnusY, magnusZ)

        -- TODO: Apply players forces

        -- Sync ball area position with ball collider position
        ball.area:setPosition(ball.collider:getPosition())
    end
end

local function updatePhysics(dt)
    state.accumulator = state.accumulator + dt

    while state.accumulator >= state.CONST_DT do
        state.world:update(state.CONST_DT)
        state.accumulator = state.accumulator - state.CONST_DT

        updateBallPhysics(state.balls)
    end
end

function lovr.update(dt)
    server.frame = server.frame + 1

    handleIncomingEvents()

    -- Run a physical simulation step
    -- Update all objects

    updatePhysics(dt)

    for index, player in ipairs(state.players_slots) do
        if player.status == "occupied" and player.peer and player.input then
            -- if player.input.lmb_pressed then
            --     local x, y, z = state.ground:getPosition()
            --     state.ground:setPosition(x, y + 0.1, z)
            -- end
            -- if player.input.rmb_pressed then
            --     local x, y, z = state.ground:getPosition()
            --     state.ground:setPosition(x, y - 0.1, z)
            -- end
        end
    end

    -- Decide if any client needs a world update and take a snapshot of the current world state
    -- if necessary
    local x, y, z = state.ground:getPosition()
    local snapshot = { ground = { x = x, y = y, z = z }, balls = {} }
    local balls = {}
    for id, ball in ipairs(state.balls) do
        local x, y, z, angle, ax, ay, az = ball.collider:getPose()
        balls[id] = { x = x, y = y, z = z, angle = angle, ax = ax, ay = ay, az = az }
    end
    snapshot.balls = balls
    sendUpdatedSnapshot(snapshot)
end

local function drawGround(pass, ground)
    local shape = ground:getShapes()[1]
    pass:setColor(96 / 255, 129 / 255, 28 / 255)
    local x, y, z, angle, ax, ay, az = ground:getPose()
    local sx, sy, sz = shape:getDimensions()
    pass:box(x, y, z, sx, sy, sz, angle, ax, ay, az)
end

local function cleanup(pass, lambda)
    lambda(pass)
    pass:setColor(1, 1, 1)
end

local function drawPlane(pass)
    pass:setColor(0x121212)
    pass:plane(0, 0.01, 0, 90, 120, -math.pi / 2, 1, 0, 0, "line", 90, 120)
    -- pass:plane(0, 0.01, 0, 90, 120, -math.pi / 2, 1, 0, 0, "line", 45, 60)
end

function lovr.draw(pass)
    pass:setSampler("nearest")
    cleanup(pass, drawPlane)
    phywire.draw(pass, state.world)

    cleanup(pass, function() drawGround(pass, state.ground) end)
    for id, ball in ipairs(state.balls) do
        b.drawBall(pass, ball)
    end

    for id, player_slot in ipairs(state.players_slots) do
        p.drawPlayer(pass, player_slot.player)
    end
end
