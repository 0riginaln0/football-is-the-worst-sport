lovr.window = require 'lovr-window'
lovr.mouse = require 'lovr-mouse'

local cam = require 'cam'
local phywire = require 'phywire'
local utils = require 'utils'

local player_pos = Vec3()
local player_vel = Vec3(0, 0, 0)
local track_cursor = false
local cursor_pos = Vec3(0, 0, 0)
local mouse_dir = Vec3(0, 0, 0)


local world
local const_dt = 0.01666666666 -- my constant dt
local accumulator = 0          -- accumulator of time to simulate


function lovr.load()
    lovr.graphics.setBackgroundColor(0x87ceeb)
    world = lovr.physics.newWorld(0, -9.81, 0, false)

    -- ground plane
    local box = world:newBoxCollider(vec3(0, -2, 0), vec3(20, 4, 20))
    box:setKinematic(true)
    -- ball
    local ballPosition = vec3(-1, 10, -1)
    local ball = world:newSphereCollider(ballPosition, 0.12):setRestitution(0.7)
end

function lovr.update(dt)
    accumulator = accumulator + dt
    while accumulator >= const_dt do
        world:update(const_dt)
        accumulator = accumulator - const_dt
    end

    player_vel = Vec3(0, 0, 0)
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

    if track_cursor then
        mouse_dir = cursor_pos - player_pos
        player_pos:add(mouse_dir * dt)
    else
        player_pos:add(player_vel:normalize() * 5 * dt)
    end
end

---@diagnostic disable-next-line: duplicate-set-field
function lovr.draw(pass)
    phywire.draw(pass, world)
    if track_cursor then
        local spot = utils.cursorToWorldPoint(pass)
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
            pass:setColor(0.4, 0, 0)
            pass:sphere(x, y, z, shape:getRadius())
        end
    end


    pass:setColor(0x40a0ff)
    pass:sphere(0, 0, 0, 0.2)
    pass:sphere(1, 0, 0, 0.2)
    pass:sphere(-1, 0, 0, 0.2)
    pass:sphere(0, 0, 1, 0.2)
    pass:sphere(0, 0, -1, 0.2)
    pass:sphere(1, 0, 1, 0.2)
    pass:sphere(4, 0, 0, 0.2)
    pass:sphere(-4, 0, 0, 0.2)
    pass:sphere(0, 0, 4, 0.2)
    pass:sphere(0, 0, -4, 0.2)
    pass:sphere(4, 0, 4, 0.2)

    pass:setColor(1, 1, 1)
    pass:text('Hold right\nmouse button\nto move\ntoward it', -2, 0.05, 0, 0.5, -math.pi / 2, 1, 0, 0)

    -- pass:setColor(0x101010)
    -- pass:plane(0, 0, 0, 20, 20, -math.pi / 2, 1, 0, 0)
    -- pass:setColor(0x505050)
    -- pass:plane(0, 0.01, 0, 20, 20, -math.pi / 2, 1, 0, 0, 'line', 100, 100)
    pass:setColor(0xD0A010)
    pass:capsule(player_pos, player_pos + vec3(0, 0.4, 0), 0.3)
    cam.center = player_pos
    cam.nudge()
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
    if key == "f8" then
        do_snapshot = true
    end
    if key == "g" then
        track_cursor = not track_cursor
    end
end

function lovr.keypressed(key)
    if key == 'escape' then
        lovr.event.quit()
    end
end

cam.integrate()
