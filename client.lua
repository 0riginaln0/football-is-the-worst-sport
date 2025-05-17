-------------
-- Imports --
-------------
lovr.window = require 'lib.lovr-window'
lovr.mouse = require 'lib.lovr-mouse'
local math = require 'math'
local inspect = require("lib.inspect").inspect
local phywire = require 'lib.phywire'
phywire.options.show_shapes = true     -- draw collider shapes (on by default)
phywire.options.show_velocities = true -- vector showing direction and magnitude of collider linear velocity
phywire.options.show_angulars = true   -- gizmo displaying the collider's angular velocity
phywire.options.show_joints = true     -- show joints between colliders
phywire.options.show_contacts = true   -- show collision contacts (quite inefficient, triples the needed collision computations)
phywire.options.wireframe = true
UI2D = require 'lib.ui2d.ui2d'
local enet = require "enet"
local protocol = require 'protocol'
local buf = require 'string.buffer'
table.clear = require 'table.clear'
local b = require "ball"
local p = require "player"
local newCam = require "lib.cam"
local cursor = require "cursor"



-- Data to get from server
local state = {
    world = nil,
    ground = nil, -- part of world
    players_slots = {
        -- 30 entries
        { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" },
        { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" },
        { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" },
        { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" },
        { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" },
        { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" }, { status = "free" },
    },
    balls = {}, -- part of world
    host = nil,
}
local my_player = {}


local cameras = {
    topdown = newCam(),
    topdown_look_around = newCam(),
    behind_the_back = newCam(),
    foreign = newCam()
}

local controls = {
    jump = "space",
    dive = "d",
    slide = "s",
    focus = "w",
    look_right = "e",
    look_left = "q",
    zoom_in = "y",
    zoom_out = "t",
}

---@class PlayerInput
---@field type ClientToServerMessage
---@field last_received_frame number|nil
---@field id number|nil
---@field spot { x: number, y: number, z: number }
---@field lmb_pressed boolean
---@field rmb_pressed boolean
---@field mmb_pressed boolean
---@field jump_button_pressed boolean
---@field dive_button_pressed boolean
---@field slide_button_pressed boolean
local input = {
    type = protocol.cts.input,
    last_received_frame = nil,
    id = nil,

    spot = { x = 0, y = 0, z = 0 },

    lmb_pressed = false,
    rmb_pressed = false,
    mmb_pressed = false,

    jump_button_pressed = false,
    dive_button_pressed = false,
    slide_button_pressed = false,
}
input.window_height, input.window_height = lovr.system.getWindowDimensions()

-- Local data
local lock_mouse = false
local track_cursor = true
local cursor_image = lovr.mouse.newCursor('res/cursor.png', 20, 20)
local messages = {}

local server = {
    address = 'localhost:6750',
    max_peers = 32,
    channel_count = 3, -- 0 for "unsequenced", 1 for "unreliable", 2 for "reliable"
    peer = nil,
}

function lovr.load()
    UI2D.Init("lovr")
    lovr.graphics.setBackgroundColor(0x87ceeb)
    lovr.mouse.setCursor(cursor_image)

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

    -- Create s_slots
    for index, slot in ipairs(state.players_slots) do
        slot.player = p.createPlayer(state.world, 40, 0, -30 + index * 2)
    end

    -- Create balls
    for i = 1, 22, 1 do
        state.balls[i] = b.createBall(state.world, i, 2, 0)
    end

    print("LOCLA BALLS", #state.balls)


    state.host = enet.host_create(nil, 1, server.channel_count)
    server.peer = state.host:connect(server.address, server.channel_count)
end

local function rad_to_degree(rad)
    return rad * 57.2958
end

local function degree_to_rad(degree)
    return degree * 0.0174533
end

local debug_menu = {
    camera_fov_degree = rad_to_degree(cameras.topdown.fov),
    camera_distance = cameras.topdown.radius,
    camera_vertical_offset = 0,
    camera_angle = rad_to_degree(cameras.topdown.polar),
    font_size = 14
}

local track_cursor = false

local function lockMouse()
    if lock_mouse then
        local pad = 2
        local x, y = lovr.mouse.getPosition()
        if x < 0 + pad then
            lovr.mouse.setX(pad)
        elseif x > input.window_width - pad then
            lovr.mouse.setX(input.window_width - pad)
        end
        if y < 0 + pad then
            lovr.mouse.setY(pad)
        elseif y > input.window_height - pad then
            lovr.mouse.setY(input.window_height - pad)
        end
    end
end

local pass_w = 0
local pass_h = 0
function lovr.update(dt)
    if track_cursor then
        local spot = cursor.cursorToWorldPoint(pass_w, pass_h, cameras.topdown, input.mouse_x, input.mouse_y)
        input.spot.x, input.spot.y, input.spot.z = spot.x, spot.y, spot.z
    end

    UI2D.InputInfo()

    local msg = buf.encode(input)
    if server.peer and input.id then -- TODO: Add state machine isntead of checking for autherization by input.id
        server.peer:send(msg, protocol.channel.unsequenced, "unsequenced")
    end


    if state.host then
        local event = state.host:service(3) -- consider to set as 0
        local count, limit = 0, 50          -- Since it isn't threaded, make sure it exits update
        while event and count < limit do
            if event.type == "receive" then
                table.insert(messages, buf.decode(event.data))
            elseif event.type == "disconnect" then
                if event.peer == server.peer then -- This should always be true due to the next statement about inbound connections
                    -- table.insert(messages, event.data)
                    -- state.host = enet.host_create(nil, 1, server.channel_count)
                    -- server.peer = state.host:connect(server.address, server.channel_count)
                    -- print("reconnecting...")
                end
            elseif event.type == "connect" then
                print("connected")
                if event.peer ~= server.peer then
                    event.peer:disconnect_now() -- Don't want other clients connecting to this client
                end
                event.peer:send(buf.encode({ type = protocol.cts.auth }), protocol.channel.reliable, "reliable")
            end
            event = state.host:check_events() -- receive any waiting messages
            count = count + 1
        end
    end

    -- Set updated world info
    for index, data in ipairs(messages) do
        if data.type == protocol.stc.update then
            if input.last_received_frame == nil or input.last_received_frame < data.snapshot.frame then
                input.last_received_frame = data.snapshot.frame
                for i = 1, 22, 1 do
                    local ball = data.snapshot.balls[i]
                    if ball == nil then goto continue end
                    state.balls[i].collider:setPose(ball.x, ball.y, ball.z, ball.angle, ball.ax, ball.ay, ball.az)
                    ::continue::
                end
                for i = 1, 30, 1 do
                    local slot = data.snapshot.players_slots[i]
                    if slot == nil then goto continue end
                    state.players_slots[i].status = slot.status
                    local x, y, z = slot.player.pos.x, slot.player.pos.y, slot.player.pos.z
                    state.players_slots[i].player.pos.x = x
                    state.players_slots[i].player.pos.y = y
                    state.players_slots[i].player.pos.z = z
                    if i == input.id then
                        cameras.topdown.center:set(x, y + debug_menu.camera_vertical_offset, z)
                    end
                    ::continue::
                end
            end
        elseif data.type == protocol.stc.id then
            print("Got id", data.id)
            input.id = data.id
            print("My player has ID:", input.id)
        end
    end
    table.clear(messages)
end

----------
-- Draw --
----------


local function cleanup(pass, lambda)
    lambda(pass)
    pass:setColor(1, 1, 1)
end

local function drawGround(pass, ground)
    local shape = ground:getShapes()[1]
    pass:setColor(96 / 255, 129 / 255, 28 / 255)
    local x, y, z, angle, ax, ay, az = ground:getPose()
    local sx, sy, sz = shape:getDimensions()
    pass:box(x, y, z, sx, sy, sz, angle, ax, ay, az)
end

local axis = 1



function lovr.draw(pass)
    local w, h = pass:getDimensions()
    pass_w = w
    pass_h = h
    lockMouse()
    --#region GUI
    pass:setProjection(1, mat4():orthographic(pass:getDimensions()))
    UI2D.Begin("Settings", 0, 0)
    do
        debug_menu.camera_fov_degree = UI2D.SliderFloat("fov", debug_menu.camera_fov_degree, 30, 130)
        cameras.topdown.fov = degree_to_rad(debug_menu.camera_fov_degree)
        cameras.topdown:resize(lovr.system.getWindowDimensions())
    end
    do
        debug_menu.camera_distance = UI2D.SliderFloat("distance", debug_menu.camera_distance, 3, 40)
        cameras.topdown.radius = debug_menu.camera_distance
        cameras.topdown:nudge()
    end
    do
        debug_menu.camera_vertical_offset = UI2D.SliderFloat("vertical offset", debug_menu.camera_vertical_offset, 0, 10)
    end
    do
        debug_menu.camera_angle = UI2D.SliderFloat("angle", debug_menu.camera_angle, 0, 70)
        cameras.topdown.polar = degree_to_rad(debug_menu.camera_angle)
        cameras.topdown:nudge()
    end
    do
        local released = false
        debug_menu.font_size, released = UI2D.SliderFloat("font size", debug_menu.font_size, 3, 33, nil, 0)

        if released then
            print("a")
            UI2D.SetFontSize(debug_menu.font_size)
        end
    end
    UI2D.End(pass)
    local ui_passes = UI2D.RenderFrame(pass)
    --#endregion GUI


    cameras.topdown:setCamera(pass)

    pass:setSampler("nearest")

    pass:setColor(0x121212)
    pass:plane(0, 0.01, 0, 90, 120, -math.pi / 2, 1, 0, 0, 'line', 45, 60)
    phywire.draw(pass, state.world)

    cleanup(pass, function() drawGround(pass, state.ground) end)

    for id, ball in ipairs(state.balls) do
        b.drawBall(pass, ball)
    end

    for id, player_slot in ipairs(state.players_slots) do
        p.drawPlayer(pass, player_slot.player)
    end


    table.insert(ui_passes, pass)
    return lovr.graphics.submit(ui_passes)
end

function lovr.quit()
    print("Cleaning up")
    -- Requests a disconnection from the peer.
    -- The message is sent on the next host:service() or host:flush().
    server.peer:disconnect(0)
    state.host:flush()

    -- A truthy value can be returned from this callback to abort quitting. But we want to quit
    return false
end

function lovr.resize(width, height)
    input.window_width, input.window_height = width, height
    cameras.topdown:resize(width, height)
end

function lovr.wheelmoved(dx, dy)
    UI2D.WheelMoved(dx, dy)
    input.wheel_moved_dx, input.wheel_moved_dy = dx, dy

    if not UI2D.HasMouse() then
        cameras.topdown:wheelmoved(dx, dy)
    end
end

function lovr.keyreleased(key, scancode, repeating)
    UI2D.KeyReleased()
    if key == "g" then
        track_cursor = not track_cursor
    end
    if key == "f11" then
        local fullscreen, fullscreentype = lovr.window.getFullscreen()
        lovr.window.setFullscreen(not fullscreen, "exclusive")
    end
    if key == "f10" then
        lock_mouse = not lock_mouse
    end
    if key == "f9" then
        lovr.mouse.setRelativeMode(not lovr.mouse.getRelativeMode())
    end
    if key == "x" then
        track_cursor = not track_cursor
    end

    if key == controls.jump then
        input.jump_button_pressed = false
    end
    if key == controls.dive then
        input.dive_button_pressed = false
    end
    if key == controls.slide then
        input.slide_button_pressed = false
    end
    if key == controls.focus then
        input.focus_button_pressed = false
    end
    if key == controls.zoom_in then
        input.zoom_in_button_pressed = false
    end
    if key == controls.zoom_out then
        input.zoom_out_button_pressed = false
    end
    if key == controls.look_right then
        input.look_right_button_pressed = false
    end
    if key == controls.look_left then
        input.look_left_button_pressed = false
    end
    if key == controls.move_camera_up then
        input.move_camera_up_button_pressed = false
    end
    if key == controls.move_camera_down then
        input.move_camera_down_button_pressed = false
    end
    if key == controls.move_camera_higher then
        input.move_camera_higher_button_pressed = false
    end
    if key == controls.move_camera_lower then
        input.move_camera_lower_button_pressed = false
    end
    if key == controls.increase_fov then
        input.increase_fov_button_pressed = false
    end
    if key == controls.decrease_fov then
        input.decrease_fov_button_pressed = false
    end
end

function lovr.keypressed(key, scancode, repeating)
    UI2D.KeyPressed(key, repeating)
    if key == 'escape' then
        lovr.event.quit()
    end
    if key == controls.jump then
        input.jump_button_pressed = true
    end
    if key == controls.dive then
        input.dive_button_pressed = true
    end
    if key == controls.slide then
        input.slide_button_pressed = true
    end
    if key == controls.focus then
        input.focus_button_pressed = true
    end
    if key == controls.zoom_in then
        input.zoom_in_button_pressed = true
    end
    if key == controls.zoom_out then
        input.zoom_out_button_pressed = true
    end
    if key == controls.look_right then
        input.look_right_button_pressed = true
    end
    if key == controls.look_left then
        input.look_left_button_pressed = true
    end
    if key == controls.move_camera_up then
        input.move_camera_up_button_pressed = true
    end
    if key == controls.move_camera_down then
        input.move_camera_down_button_pressed = true
    end
    if key == controls.move_camera_higher then
        input.move_camera_higher_button_pressed = true
    end
    if key == controls.move_camera_lower then
        input.move_camera_lower_button_pressed = true
    end
    if key == controls.increase_fov then
        input.increase_fov_button_pressed = true
    end
    if key == controls.decrease_fov then
        input.decrease_fov_button_pressed = true
    end
end

function lovr.textinput(text, code)
    UI2D.TextInput(text)
end

function lovr.mousemoved(x, y, dx, dy)
    input.mouse_x = x
    input.mouse_y = y
    input.mouse_dx = dx
    input.mouse_dy = dy

    cameras.topdown:mousemoved(x, y, dx, dy)
end

function lovr.mousepressed(x, y, button)
    if button == 1 then
        input.lmb_pressed = true
    elseif button == 2 then
        input.rmb_pressed = true
    elseif button == 3 then
        input.mmb_pressed = true
    end

    if button == 1 and not UI2D.HasMouse() then
        -- Code to handle lmb pressed if not in menu
    end
end

function lovr.mousereleased(x, y, button)
    if button == 1 then
        input.lmb_pressed = false
    elseif button == 2 then
        input.rmb_pressed = false
    elseif button == 3 then
        input.mmb_pressed = false
    end
end
