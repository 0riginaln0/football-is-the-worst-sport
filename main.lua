lovr.window = require 'lovr-window'
lovr.mouse = require 'lovr-mouse'

local cam = require 'cam'

local player_pos = Vec3()
local player_vel = Vec3(0, 0, 0)
local track_cursor = false
local cursor_pos = Vec3(0, 0, 0)
local mouse_dir = Vec3(0, 0, 0)

function lovr.load()
    lovr.graphics.setBackgroundColor(0x87ceeb)
end

-- next three functions convert mouse coordinate from screen to the 3D position on the ground plane
local function getWorldFromScreen(pass)
    local w, h = pass:getDimensions()
    local clip_from_screen = mat4(-1, -1, 0):scale(2 / w, 2 / h, 1)
    local view_pose = mat4(pass:getViewPose(1))
    local view_proj = pass:getProjection(1, mat4())
    return view_pose:mul(view_proj:invert()):mul(clip_from_screen)
end


local function getRay(world_from_screen, distance)
    local NEAR_PLANE = 0.01
    distance = distance or 1e3
    local ray = {}
    local x, y = lovr.mouse.getPosition()
    ray.origin = vec3(world_from_screen:mul(x, y, NEAR_PLANE / NEAR_PLANE))
    ray.target = vec3(world_from_screen:mul(x, y, NEAR_PLANE / distance))
    return ray
end


local function mouseOnGround(ray)
    if ray.origin:distance(ray.target) < 1e-2 then
        return vec3(0, 0, 0)
    end
    local ray_direction = (ray.target - ray.origin):normalize()
    -- intersect the ray onto ground plane
    local plane_direction = vec3(0, 1, 0)
    local dot = ray_direction:dot(plane_direction)
    if dot == 0 then
        return vec3(0, 0, 0)
    end
    ---@diagnostic disable-next-line: undefined-field
    local ray_length = (-ray.origin):dot(plane_direction) / dot
    local hit_spot = ray.origin + ray_direction * ray_length
    hit_spot.y = 0.0
    return hit_spot
end


function lovr.update(dt)
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

    mouse_dir = cursor_pos - player_pos
    player_pos:add(mouse_dir * dt)
end

---@diagnostic disable-next-line: duplicate-set-field
function lovr.draw(pass)
    -- player control
    local dt = lovr.timer.getDelta()

    if track_cursor then
        local world_from_screen = getWorldFromScreen(pass)
        local ray = getRay(world_from_screen)
        local spot = mouseOnGround(ray)
        print("spot:", spot)
        -- track_cursor = false
        cursor_pos.x = spot.x
        cursor_pos.y = spot.y
        cursor_pos.z = spot.z
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

    pass:setColor(0x101010)
    pass:plane(0, 0, 0, 20, 20, -math.pi / 2, 1, 0, 0)
    pass:setColor(0x505050)
    pass:plane(0, 0.01, 0, 20, 20, -math.pi / 2, 1, 0, 0, 'line', 100, 100)
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
