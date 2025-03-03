local m = {}

-- next three functions convert mouse coordinate from screen to the 3D position on the ground plane
local function getWorldFromScreen(pass, cam)
    local w, h = pass:getDimensions()
    local clip_from_screen = mat4(-1, -1, 0):scale(2 / w, 2 / h, 1)
    -- local view_pose = pass:getViewPose(1, mat4(), true):invert()
    local view_pose = lovr.math.mat4(cam.pose)
    -- local view_proj = pass:getProjection(1, mat4())
    local view_proj = lovr.math.mat4(cam.projection)
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

function m.cursorToWorldPoint(pass, cam)
    local world_from_screen = getWorldFromScreen(pass, cam)
    local ray = getRay(world_from_screen)
    local spot = mouseOnGround(ray)
    return spot
end

return m
