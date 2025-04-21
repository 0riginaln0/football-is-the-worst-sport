-------------
-- Imports --
-------------
lovr.window = require 'lib.lovr-window'
lovr.mouse = require 'lib.lovr-mouse'
local math = require 'math'
local dbg = require 'lib.debugger'
local phywire = require 'lib.phywire'
phywire.options.show_shapes = true     -- draw collider shapes (on by default)
phywire.options.show_velocities = true -- vector showing direction and magnitude of collider linear velocity
phywire.options.show_angulars = true   -- gizmo displaying the collider's angular velocity
phywire.options.show_joints = true     -- show joints between colliders
phywire.options.show_contacts = true   -- show collision contacts (quite inefficient, triples the needed collision computations)
phywire.options.wireframe = true
UI2D = require 'lib.ui2d.ui2d'
local enet = require("enet")
local protocol = require 'protocol'
local buf = require 'string.buffer'
table.clear = require 'table.clear'

local controls = {
    jump = "d",
    header = "s",
    slide = "d",
    focus = "w",
    look_right = "e",
    look_left = "q",
    zoom_in = "y",
    zoom_out = "t",
    move_camera_up_button_pressed = "h",
    move_camera_down_button_pressed = "g",
    move_camera_higher_button_pressed = "n",
    move_camera_lower_button_pressed = "b",
    increase_fov_button_pressed = "z",
    decrease_fov_button_pressed = "c",
}

local input = {
    type = protocol.cts.input,
    last_received_frame = nil,
    id = nil,

    window_width = 0,
    window_height = 0,

    mouse_x = 0,
    mouse_y = 0,
    mouse_dx = 0,
    mouse_dy = 0,

    wheel_moved_dx = 0,
    wheel_moved_dy = 0,

    lmb_pressed = false,
    rmb_pressed = false,
    mmb_pressed = false,

    jump_button_pressed = false,
    header_button_pressed = false,
    slide_button_pressed = false,
    focus_button_pressed = false,
    zoom_in_button_pressed = false,
    zoom_out_button_pressed = false,
    look_right_button_pressed = false,
    look_left_button_pressed = false,
    move_camera_up_button_pressed = false,
    move_camera_down_button_pressed = false,
    move_camera_higher_button_pressed = false,
    move_camera_lower_button_pressed = false,
    increase_fov_button_pressed = false,
    decrease_fov_button_pressed = false,
}
input.window_height, input.window_height = lovr.system.getWindowDimensions()

function lovr.mousemoved(x, y, dx, dy)
    input.mouse_x = x
    input.mouse_y = y
    input.mouse_dx = dx
    input.mouse_dy = dy
end

-- Local data
local lock_mouse = false
local track_cursor = true
local cursor_image = lovr.mouse.newCursor('res/cursor.png', 20, 20)
local messages = {}

local server = {
    address = 'localhost:6750',
    max_peers = 32,
    channel_count = 2, -- 0 for "unsequenced", 1 for "reliable"
    peer = nil,
}

-- Data to get from server
local state = {
    cam = nil,
    turn_cam = nil,
    world = nil,
    host = nil,
}

----------
-- Load --
----------
function lovr.load()
    UI2D.Init("lovr")
    lovr.graphics.setBackgroundColor(0x87ceeb)
    lovr.mouse.setCursor(cursor_image)
    state.host = enet.host_create(nil, 1, 2)
    server.peer = state.host:connect(server.address)
end

------------
-- Update --
------------
function lovr.update(dt)
    UI2D.InputInfo()

    local msg = buf.encode(input)
    if server.peer and input.id then
        server.peer:send(msg)
    end


    if state.host then
        local event = state.host:service(3) -- consider to set as 0
        local count, limit = 0, 50          -- Since it isn't threaded, make sure it exits update
        while event and count < limit do
            if event.type == "receive" then
                table.insert(messages, buf.decode(event.data))
            elseif event.type == "disconnect" then
                if event.peer == server.peer then -- This should always be true due to the next statement about inbound connections
                    table.insert(messages, "Disconnected: " .. event.data)
                end
            elseif event.type == "connect" then
                print("connected")
                if event.peer ~= server.peer then
                    event.peer:disconnect_now() -- Don't want other clients connecting to this client
                end
                event.peer:send(buf.encode({ type = protocol.cts.auth }))
            end
            event = state.host:check_events() -- receive any waiting messages
            count = count + 1
        end
    end

    -- Set updated world info
    for index, data in ipairs(messages) do
        if data.type == protocol.stc.id then
            print("Got id", data.id)
            input.id = data.id
        end
    end
    table.clear(messages)
end

----------
-- Draw --
----------

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
function lovr.draw(pass)
    lockMouse()
    -- GUI CODE
    pass:setProjection(1, mat4():orthographic(pass:getDimensions()))
    local ui_passes = UI2D.RenderFrame(pass)
    -- GUI CODE

    pass:setColor(0x121212)
    pass:plane(0, 0.01, 0, 90, 120, -math.pi / 2, 1, 0, 0, 'line', 45, 60)

    -- phywire.draw(pass, world)
    -- for i, collider in ipairs(world:getColliders()) do
    --     local shape = collider:getShapes()[1]
    --     local shapeType = shape:getType()
    --     local x, y, z, angle, ax, ay, az = collider:getPose()
    --     if shapeType == 'box' then
    --         pass:setColor(0.1, 0.5, 0.1)
    --         local sx, sy, sz = shape:getDimensions()
    --         pass:box(x, y, z, sx, sy, sz, angle, ax, ay, az)
    --     elseif shapeType == 'sphere' then
    --         pass:setColor(1, 1, 1)
    --         pass:sphere(x, y, z, shape:getRadius())
    --     elseif shapeType == "capsule" then
    --         pass:setColor(0xD0A010)
    --         pass:capsule(x, y, z, 0.4, 1.4, angle, ax, ay, az)
    --     end
    -- end


    -- pass:setColor(0x40a0ff)
    -- pass:sphere(0, 0, 0, 0.2)
    -- pass:sphere(1, 0, 0, 0.2)
    -- pass:sphere(-1, 0, 0, 0.2)

    -- pass:setColor(1, 1, 1)

    -- GUI CODE
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
end

function lovr.wheelmoved(dx, dy)
    UI2D.WheelMoved(dx, dy)
    input.wheel_moved_dx, input.wheel_moved_dy = dx, dy

    if not UI2D.HasMouse() then
        -- something
    end
end

function lovr.keyreleased(key, scancode, repeating)
    UI2D.KeyReleased()
    if key == "f11" then
        local fullscreen, fullscreentype = lovr.window.getFullscreen()
        lovr.window.setFullscreen(not fullscreen, fullscreentype or "desktop")
    end
    if key == "f10" then
        lock_mouse = not lock_mouse
        -- lovr.mouse.setRelativeMode(not lovr.mouse.getRelativeMode())
    end
    if key == "x" then
        track_cursor = not track_cursor
    end
end

function lovr.keypressed(key, scancode, repeating)
    UI2D.KeyPressed(key, repeating)
    if key == 'escape' then
        lovr.event.quit()
    end


    input.jump_button_pressed = true
    input.header_button_pressed = true
    input.slide_button_pressed = true
    input.focus_button_pressed = true
    input.zoom_in_button_pressed = true
    input.zoom_out_button_pressed = true
    input.look_right_button_pressed = true
    input.look_left_button_pressed = true
    input.move_camera_up_button_pressed = true
    input.move_camera_down_button_pressed = true
    input.move_camera_higher_button_pressed = true
    input.move_camera_lower_button_pressed = true
    input.increase_fov_button_pressed = true
    input.decrease_fov_button_pressed = true
end

function lovr.textinput(text, code)
    UI2D.TextInput(text)
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
