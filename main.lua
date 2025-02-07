lovr.window = require 'lovr-window'
lovr.mouse = require 'lovr-mouse'
-- local cam = require 'cam'

function lovr.load()
    lovr.graphics.setBackgroundColor(0x181818)
    lovr.mouse.setRelativeMode(false)

    camera = {
        transform = lovr.math.newMat4(),
        position = lovr.math.newVec3(0, 10, 0),
        movespeed = 10,
        pitch = 0,
        yaw = 0
    }
end

local free_cam = true
local do_snapshot = false

local function debug(...)
    if do_snapshot then
        print(...)
    end
end

function lovr.update(dt)
    local velocity = vec4()

    -- Step 1: Get the mouse position
    local mouseX, mouseY = lovr.mouse.getPosition()
    debug("MouseX", mouseX, "MouseY", mouseY)

    -- Step 2: Get the window dimensions
    local width, height = lovr.system.getWindowDimensions()
    debug("width", width, "height", height)

    -- Step 3: Calculate normalized device coordinates (NDC)
    local ndcX = (mouseX / width) * 2 - 1
    local ndcY = 1 - (mouseY / height) * 2 -- Invert Y for NDC
    debug("X NDC", ndcX, "Y NDC", ndcY)

    debug("Camera pos:", camera.position)

    if lovr.system.isKeyDown('w', 'up') then
        velocity.z = -1
    elseif lovr.system.isKeyDown('s', 'down') then
        velocity.z = 1
    end

    if lovr.system.isKeyDown('a', 'left') then
        velocity.x = -1
    elseif lovr.system.isKeyDown('d', 'right') then
        velocity.x = 1
    end

    if lovr.system.isKeyDown('q') then
        camera.yaw = camera.yaw + 1 * .002
    end
    if lovr.system.isKeyDown('e') then
        camera.yaw = camera.yaw - 1 * .002
    end

    if #velocity > 0 then
        velocity:normalize()
        velocity:mul(camera.movespeed * dt)
        camera.position:add(camera.transform:mul(velocity).xyz)
    end

    camera.transform:identity()
    camera.transform:translate(0, 0, 0)
    camera.transform:translate(camera.position)
    camera.transform:rotate(camera.yaw, 0, 1, 0)
    camera.transform:rotate(camera.pitch, 1, 0, 0)
    do_snapshot = false
end

local plane_width, plane_height = 100, 100

function lovr.draw(pass)
    pass:push()
    pass:setViewPose(1, camera.transform)
    pass:setColor(0xff0000)
    pass:cube(0, 0.5, 0, 1, lovr.timer.getTime())
    pass:setColor(0xffffff)
    pass:plane(0, 0, 0, plane_width, plane_height, math.pi / 2, 1, 0, 0)
    pass:pop()
end

function lovr.mousemoved(x, y, dx, dy)
    if free_cam then
        camera.pitch = camera.pitch - dy * .004
        camera.yaw = camera.yaw - dx * .004
    end
end

function lovr.keypressed(key)
    if key == 'escape' then
        lovr.event.quit()
    end
end

function lovr.keyreleased(key, scancode, repeating)
    if key == "f" then
        free_cam = not free_cam
    end
    if key == "f11" then
        print("f11")
        local fullscreen, fullscreentype = lovr.window.getFullscreen()
        print("Fullscreen? ", fullscreen)
        lovr.window.setFullscreen(not fullscreen, fullscreentype or "exclusive")
    end
    if key == "f10" then
        print("f10 -----------------")
        print("Mouse mode: ", lovr.mouse.getRelativeMode())
        lovr.mouse.setRelativeMode(false)
        print("f10 -----setfalse----")
        print("Mouse mode: ", lovr.mouse.getRelativeMode())
    end
    if key == "f9" then
        print("f9  =================")
        print("Mouse mode: ", lovr.mouse.getRelativeMode())
        lovr.mouse.setRelativeMode(true)
        print("f9  =====settrue=====")
        print("Mouse mode: ", lovr.mouse.getRelativeMode())
    end
    if key == "f8" then
        do_snapshot = true
    end
end

-- -----------------------------------------------------------------

-- cam.integrate()
