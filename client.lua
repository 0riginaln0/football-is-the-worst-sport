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


-- Data to send to server
local input = {
    server_frame = 0,

    window_width = 0,
    window_height = 0,

    mouse_x = 0,
    mouse_y = 0,
    lmb_pressed = false,
    rmb_pressed = false,
    mmb_pressed = false,
    wheel_moved_dx = 0,
    wheel_moved_dy = 0,

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

-- Local data
local lock_mouse = false
local track_cursor = true
local client_frame = 0 -- For managing just_released and just_pressed
local cursor_image = lovr.mouse.newCursor('res/cursor.png', 20, 20)

-- Data to get from server
local cam = nil
local turn_cam = nil
local world = nil

----------
-- Load --
----------
function lovr.load()
    UI2D.Init("lovr")
    lovr.graphics.setBackgroundColor(0x87ceeb)
    lovr.mouse.setCursor(cursor_image)
end

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

------------
-- Update --
------------
function lovr.update(dt)
    client_frame = client_frame + 1
    UI2D.InputInfo()
end

----------
-- Draw --
----------
function lovr.draw(pass)
    lockMouse()
    -- GUI CODE
    pass:setProjection(1, mat4():orthographic(pass:getDimensions()))
    local ui_passes = UI2D.RenderFrame(pass)
    -- GUI CODE

    pass:setColor(0x121212)
    pass:plane(0, 0.01, 0, 90, 120, -math.pi / 2, 1, 0, 0, 'line', 45, 60)

    phywire.draw(pass, world)
    for i, collider in ipairs(world:getColliders()) do
        local shape = collider:getShapes()[1]
        local shapeType = shape:getType()
        local x, y, z, angle, ax, ay, az = collider:getPose()
        if shapeType == 'box' then
            pass:setColor(0.1, 0.5, 0.1)
            local sx, sy, sz = shape:getDimensions()
            pass:box(x, y, z, sx, sy, sz, angle, ax, ay, az)
        elseif shapeType == 'sphere' then
            pass:setColor(1, 1, 1)
            pass:sphere(x, y, z, shape:getRadius())
        elseif shapeType == "capsule" then
            pass:setColor(0xD0A010)
            pass:capsule(x, y, z, 0.4, 1.4, angle, ax, ay, az)
        end
    end


    pass:setColor(0x40a0ff)
    pass:sphere(0, 0, 0, 0.2)
    pass:sphere(1, 0, 0, 0.2)
    pass:sphere(-1, 0, 0, 0.2)

    pass:setColor(1, 1, 1)

    -- GUI CODE
    table.insert(ui_passes, pass)
    return lovr.graphics.submit(ui_passes)
end

---------------------
-- Other Callbacks --
---------------------
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
    if key == "g" then
        track_cursor = not track_cursor
    end
    if key == "k" then
        print("k")
    end
end

function lovr.keypressed(key, scancode, repeating)
    UI2D.KeyPressed(key, repeating)
    if key == 'escape' then
        lovr.event.quit()
    end
    if key == "space" then
        space_just_pressed = true
    end
    if key == "w" then
        w_just_pressed = true
    end
    if key == "x" then
        x_just_pressed = true
    end
    if key == "v" then
        v_just_pressed = true
    end
    if key == "t" then
        t_just_pressed = true
        -- print(dbg.pretty({ a = 2, x = 44 }))
    end
    if key == "y" then
        y_just_pressed = true
    end
    if key == '0' then
        print(lovr.timer.getFPS())
    end
    if key == '9' then
        print("---------------------------------------")
        for property, value in pairs(cam) do
            if type(value) ~= "function" then
                print(property, dbg.pretty(value))
            end
        end
    end
end

function lovr.textinput(text, code)
    UI2D.TextInput(text)
end

function lovr.mousepressed(x, y, button)
    if button == 1 and not UI2D.HasMouse() then
        -- Code to handle lmb pressed if not in menu
    end
end
