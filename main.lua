-------------
-- Imports --
-------------
lovr.window = require 'utils.lovr-window'
lovr.mouse = require 'utils.lovr-mouse'

local cam = require 'utils.cam'
cam.zoom_speed = 10
cam.polar_upper = 30 * 0.0174533
cam.polar_lower = math.pi / 2 - cam.polar_upper

local function incrementFov(cam, inc)
    cam.fov = cam.fov + inc
    cam.resize(lovr.system.getWindowDimensions())
    print("New FOV:", cam.fov * 57.2958)
end


local phywire = require 'utils.phywire'
local math = require 'utils.math'


---------------------------
-- Constants & Variables --
---------------------------
local player_pos = Vec3()
local player_vel = Vec3(0, 0, 0)
local track_cursor = false
local cursor_pos = Vec3(0, 0, 0)
local mouse_dir = Vec3(0, 0, 0)

local world
local const_dt = 0.01666666666 -- my constant dt
local accumulator = 0          -- accumulator of time to simulate

local ball
local ball_radius = 0.25
local init_ball_position = vec3(-1, 10, -1)
local k = 0.001 -- Adjust this constant based on the desired curve effect

local function calculateMagnusForce(ball)
    local angular_vx, angular_vy, angular_vz = ball:getAngularVelocity() -- Get the ball's spin (ω)
    local linear_vx, linear_vy, linear_vz = ball:getLinearVelocity()     -- Get the ball's velocity (v)

    -- Calculate the cross product ω × v
    local magnusX = angular_vy * linear_vz - angular_vz * linear_vy
    local magnusY = angular_vz * linear_vx - angular_vx * linear_vz
    local magnusZ = angular_vx * linear_vy - angular_vy * linear_vx

    -- Scale the Magnus force by the constant k
    return magnusX * k, magnusY * k, magnusZ * k
end

local function resetBallVelocity(ball)
    ball:setAngularVelocity(0, 0, 0)
    ball:setLinearVelocity(0, 0, 0)
end


-----------
-- Input --
-----------
local space_just_pressed = false
local w_just_pressed = false
local a_just_pressed = false
local s_just_pressed = false
local d_just_pressed = false
local x_just_pressed = false
local v_just_pressed = false



----------
-- Load --
----------
function lovr.load()
    lovr.graphics.setBackgroundColor(0x87ceeb)
    world = lovr.physics.newWorld(0, -9.81, 0, false)
    world:setAngularDamping(0.009)
    world:setLinearDamping(0.001)

    -- ground plane
    local box = world:newBoxCollider(vec3(0, -2, 0), vec3(90, 4, 120))
    box:setKinematic(true)
    -- ball
    ball = world:newSphereCollider(init_ball_position, ball_radius)
    ball:setRestitution(0.7)
    ball:setFriction(0.7)
    ball:setMass(0.44)
end

------------
-- Update --
------------
function lovr.update(dt)
    accumulator = accumulator + dt
    while accumulator >= const_dt do
        world:update(const_dt)
        accumulator = accumulator - const_dt

        if space_just_pressed then
            ball:applyForce(0, 77, 0)
            space_just_pressed = false
        end

        if w_just_pressed then
            ball:applyTorque(1, 0, 0)
            w_just_pressed = false
        end
        if a_just_pressed then
            ball:applyTorque(0, 0, -1)
            a_just_pressed = false
        end
        if s_just_pressed then
            ball:applyTorque(-1, 0, 0)
            s_just_pressed = false
        end
        if d_just_pressed then
            ball:applyTorque(0, 0, 1)
            d_just_pressed = false
        end
        if x_just_pressed then
            resetBallVelocity(ball)
            ball:applyForce(0, 200, -500)
            ball:applyTorque(0, 200, 0)
            x_just_pressed = false
        end
        if v_just_pressed then
            resetBallVelocity(ball)
            ball:applyForce(0, 200, 500)
            ball:applyTorque(0, 200, 0)
            v_just_pressed = false
        end
        local magnusX, magnusY, magnusZ = calculateMagnusForce(ball)
        ball:applyForce(magnusX, magnusY, magnusZ) -- Apply the Magnus force
    end

    player_vel = Vec3(0, 0, 0)

    -- Camera controls
    if lovr.system.isKeyDown('q') then
        cam.nudge(-1 * dt)
    end
    if lovr.system.isKeyDown('e') then
        cam.nudge(1 * dt)
    end
    if lovr.system.isKeyDown('z') then
        cam.nudge(0, -1 * dt, 0)
    end
    if lovr.system.isKeyDown('c') then
        cam.nudge(0, 1 * dt, 0)
    end
    if lovr.system.isKeyDown('r') then
        incrementFov(cam, 0.001)
    end
    if lovr.system.isKeyDown('f') then
        incrementFov(cam, -0.001)
    end

    -- Player movement
    if track_cursor then
        mouse_dir = cursor_pos - player_pos
        player_pos:add(mouse_dir * dt)
    else
        if lovr.system.isKeyDown('w', 'up') then
            player_vel.z = -1
        elseif lovr.system.isKeyDown('s', 'down') then
            player_vel.z = 1
        end

        if lovr.system.isKeyDown('a', 'left') then
            player_vel.x = -1
        elseif lovr.system.isKeyDown('d', 'right') then
            player_vel.x = 1
        end
        player_pos:add(player_vel:normalize() * 5 * dt)
    end
end

----------
-- Draw --
----------
function lovr.draw(pass)
    cam.setCamera(pass)

    phywire.draw(pass, world)
    if track_cursor then
        local spot = math.cursorToWorldPoint(pass)
        cursor_pos.x = spot.x
        cursor_pos.y = spot.y
        cursor_pos.z = spot.z
    end

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
        end
    end


    pass:setColor(0x40a0ff)
    pass:sphere(0, 0, 0, 0.2)
    pass:sphere(1, 0, 0, 0.2)
    pass:sphere(-1, 0, 0, 0.2)

    pass:setColor(1, 1, 1)
    pass:setColor(0xD0A010)
    pass:capsule(player_pos, player_pos + vec3(0, 1.4, 0), 0.4)
    cam.center = player_pos
    cam.nudge()
end

---------------------
-- Other Callbacks --
---------------------

function lovr.resize(width, height)
    cam.resize(width, height)
end

function lovr.wheelmoved(dx, dy)
    cam.wheelmoved(dx, dy)
end

function lovr.keyreleased(key, scancode, repeating)
    if key == "f11" then
        print("f11")
        local fullscreen, fullscreentype = lovr.window.getFullscreen()
        print("Fullscreen? ", fullscreen)
        lovr.window.setFullscreen(not fullscreen, fullscreentype or "exclusive")
    end
    if key == "f10" then
        print("f10 -----------------")
        lovr.mouse.setRelativeMode(not lovr.mouse.getRelativeMode())
        print("Mouse mode: ", lovr.mouse.getRelativeMode())
    end
    if key == "g" then
        track_cursor = not track_cursor
    end
end

function lovr.keypressed(key)
    if key == 'escape' then
        lovr.event.quit()
    end
    if key == "space" then
        print("space pressed")
        space_just_pressed = true
    end
    if key == "w" then
        print("w pressed")
        w_just_pressed = true
    end
    if key == "a" then
        print("a pressed")
        a_just_pressed = true
    end
    if key == "s" then
        print("s pressed")
        s_just_pressed = true
    end
    if key == "d" then
        print("d pressed")
        d_just_pressed = true
    end
    if key == "x" then
        print("x pressed")
        x_just_pressed = true
    end
    if key == "v" then
        print("v pressed")
        v_just_pressed = true
    end
end
