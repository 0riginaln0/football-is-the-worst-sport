-------------
-- Imports --
-------------
lovr.window = require 'lib.lovr-window'
lovr.mouse = require 'lib.lovr-mouse'
local math = require 'math'
local lume = require 'lib.lume'
local dbg = require 'lib.debugger'
local newCam = require 'lib.cam'
local tween = require 'lib.tween'
local phywire = require 'lib.phywire'
phywire.options.show_shapes = true     -- draw collider shapes (on by default)
phywire.options.show_velocities = true -- vector showing direction and magnitude of collider linear velocity
phywire.options.show_angulars = true   -- gizmo displaying the collider's angular velocity
phywire.options.show_joints = true     -- show joints between colliders
phywire.options.show_contacts = true   -- show collision contacts (quite inefficient, triples the needed collision computations)
local cursor = require 'utils.cursor'
local newPlayer = require 'player'


---------------------------
-- Constants & Variables --
---------------------------
SLIDE_KEY = "a"
DIVE_KEY = "s"
JUMP_KEY = "d"
SHOT_KEY = 1
FAST_SHOT_KEY = 2


WINDOW_WIDTH, WINDOW_HEIGHT = lovr.system.getWindowDimensions()
MOUSE_LOCK = false
local world
local CONST_DT = 0.01666666666 -- my constant dt
local accumulator = 0          -- accumulator of time to simulate

local ground

-- Ball
local ball
local BALL_RADIUS = 0.25
local INIT_BALL_POSITION = vec3(-1, 10, -1)
local K = 0.001 -- Adjust this constant based on the desired curve effect

local function calculateMagnusForce(ball)
   -- Get the ball's spin (ω)
   local angular_vx, angular_vy, angular_vz = ball:getAngularVelocity()
   -- Get the ball's velocity (v)
   local linear_vx, linear_vy, linear_vz = ball:getLinearVelocity()
   -- Calculate the cross product ω × v
   local magnusX = angular_vy * linear_vz - angular_vz * linear_vy
   local magnusY = angular_vz * linear_vx - angular_vx * linear_vz
   local magnusZ = angular_vx * linear_vy - angular_vy * linear_vx
   -- Scale the Magnus force by the constant K
   return magnusX * K, magnusY * K, magnusZ * K
end

local function resetBallVelocity(ball)
   ball:setAngularVelocity(0, 0, 0)
   ball:setLinearVelocity(0, 0, 0)
end

local track_cursor = true

-- Cameras
local cam = newCam()
cam.zoom_speed = 10
cam.polar_upper = 30 * 0.0174533
cam.polar_lower = math.pi / 2 - cam.polar_upper
local cam_height = 0

local turn_cam = newCam()
turn_cam.zoom_speed = cam.zoom_speed
turn_cam.polar_upper = cam.polar_upper
turn_cam.polar_lower = cam.polar_lower

local cam_tween_base = { value = 0 }
local cam_tween = nil
local cam_prev_rad_dt = 0

-----------
-- Input --
-----------
local space_just_pressed = false
local w_just_pressed = false
local x_just_pressed = false
local v_just_pressed = false
local t_just_pressed = false
local y_just_pressed = false

----------
-- Load --
----------
function lovr.load()
   lovr.graphics.setBackgroundColor(0x87ceeb)
   world = lovr.physics.newWorld({ tags = { "ground", "ball", "player" } })
   -- world:setAngularDamping(0.009)
   -- world:setLinearDamping(0.001)

   -- ground plane
   ground = world:newBoxCollider(vec3(0, -2, 0), vec3(90, 4, 120))
   ground:setFriction(0.2)
   ground:setKinematic(true)
   ground:setTag("ground")
   -- ball
   ball = world:newSphereCollider(INIT_BALL_POSITION, BALL_RADIUS)
   ball:setRestitution(0.7)
   ball:setFriction(0.7)
   ball:setLinearDamping(0.1)
   ball:setAngularDamping(0.1)
   ball:setMass(0.44)
   ball:setContinuous(true)
   ball:setTag("ball")

   -- player
   player = newPlayer(world)


   -- Parsing cli arguments
   for _, value in pairs(arg) do
      if value == '--hb' then -- Enable heartbeat
         local heartbeat_file = io.open("heartbeat.lua", 'r')
         if not heartbeat_file then
            print("no hearbeat.lua file found")
            os.exit(-1)
         end
         local heartbeat_code = heartbeat_file:read("*a")
         local thread = lovr.thread.newThread(heartbeat_code)
         thread:start()
         heartbeat_file:close()
      end
   end

   MY_CURSOR = lovr.mouse.newCursor('res/cursor.png', 20, 20)
   lovr.mouse.setCursor(MY_CURSOR)
end

local function updateCams()
   local x, y, z = player.collider:getPosition()
   cam.center.x = x
   cam.center.y = y + cam_height
   cam.center.z = z
   turn_cam.center.x = cam.center.x
   turn_cam.center.y = cam.center.y
   turn_cam.center.z = cam.center.z
   cam.nudge()
   turn_cam.nudge()
end

local function updatePhysics(dt)
   accumulator = accumulator + dt
   while accumulator >= CONST_DT do
      world:update(CONST_DT)
      accumulator = accumulator - CONST_DT

      if space_just_pressed then
         ball:applyForce(0, 77, 0)
         space_just_pressed = false
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

      player:updatePlayerPhysics(CONST_DT)
      updateCams()
   end
   player:updatePlayer()
end

local function lockMouse()
   if MOUSE_LOCK then
      local pad = 2
      local x, y = lovr.mouse.getPosition()
      if x < 0 + pad then
         lovr.mouse.setX(pad)
      elseif x > WINDOW_WIDTH - pad then
         lovr.mouse.setX(WINDOW_WIDTH - pad)
      end
      if y < 0 + pad then
         lovr.mouse.setY(pad)
      elseif y > WINDOW_HEIGHT - pad then
         lovr.mouse.setY(WINDOW_HEIGHT - pad)
      end
   end
end

------------
-- Update --
------------
function lovr.update(dt)
   lockMouse()
   updatePhysics(dt)

   if w_just_pressed then
      local look_vector = cam.getLookVector()
      look_vector.y = 0
      local turn_angle = player.mouse_dir:angle(look_vector)
      local cross_product = look_vector:cross(player.mouse_dir)
      if cross_product.y > 0 then
         cam_tween = tween.new(0.13, cam_tween_base, { value = -turn_angle }, tween.easing.linear)
      else
         cam_tween = tween.new(0.13, cam_tween_base, { value = turn_angle }, tween.easing.linear)
      end
      w_just_pressed = false
   end
   if lovr.system.isKeyDown('t') then
      cam.wheelmoved(0, -0.05)
      turn_cam.wheelmoved(0, -0.05)
   end
   if lovr.system.isKeyDown('y') then
      cam.wheelmoved(0, 0.05)
      turn_cam.wheelmoved(0, 0.05)
   end
   if cam_tween then
      local complete = cam_tween:update(dt)
      local cam_cur_rad_dt = cam_tween_base.value - cam_prev_rad_dt
      cam_prev_rad_dt = cam_prev_rad_dt + cam_cur_rad_dt
      cam.nudge(cam_cur_rad_dt)
      if complete then
         cam_tween = nil
         cam_prev_rad_dt = 0
         cam_tween_base.value = 0
      end
   end
   if lovr.system.isKeyDown('q') then
      cam.nudge(-1 * dt)
      turn_cam.nudge(-1 * dt)
   end
   if lovr.system.isKeyDown('e') then
      cam.nudge(1 * dt)
      turn_cam.nudge(1 * dt)
   end
   if lovr.system.isKeyDown('z') then
      cam.nudge(0, -1 * dt)
      turn_cam.nudge(0, -1 * dt)
   end
   if lovr.system.isKeyDown('c') then
      cam.nudge(0, 1 * dt)
      turn_cam.nudge(0, 1 * dt)
   end
   if lovr.system.isKeyDown('b') then
      cam_height = cam_height + 1 * dt
   end
   if lovr.system.isKeyDown('n') then
      cam_height = cam_height - 1 * dt
   end
   if lovr.system.isKeyDown('r') then
      cam.incrementFov(0.001)
      turn_cam.incrementFov(0.001)
   end
   if lovr.system.isKeyDown('f') then
      cam.incrementFov(-0.001)
      turn_cam.incrementFov(-0.001)
   end
end

----------
-- Draw --
----------
function lovr.draw(pass)
   -- Switch between cameras based on input
   if lovr.system.isKeyDown('i') then
      turn_cam.setCamera(pass)
   else
      cam.setCamera(pass)
   end


   pass:setColor(0x121212)
   pass:plane(0, 0.01, 0, 90, 120, -math.pi / 2, 1, 0, 0, 'line', 45, 60)

   phywire.draw(pass, world)
   if track_cursor then
      local spot = cursor.cursorToWorldPoint(pass, cam)
      player.cursor_pos.x = spot.x
      player.cursor_pos.y = spot.y
      player.cursor_pos.z = spot.z
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
end

---------------------
-- Other Callbacks --
---------------------
function lovr.resize(width, height)
   WINDOW_WIDTH, WINDOW_HEIGHT = width, height
   cam.resize(width, height)
   turn_cam.resize(width, height)
end

function lovr.wheelmoved(dx, dy)
   cam.wheelmoved(dx, dy)
   turn_cam.wheelmoved(dx, dy)
end

function lovr.keyreleased(key, scancode, repeating)
   if key == "f11" then
      local fullscreen, fullscreentype = lovr.window.getFullscreen()
      lovr.window.setFullscreen(not fullscreen, fullscreentype or "desktop")
   end
   if key == "f10" then
      MOUSE_LOCK = not MOUSE_LOCK
      -- lovr.mouse.setRelativeMode(not lovr.mouse.getRelativeMode())
   end
   if key == "g" then
      track_cursor = not track_cursor
   end
   if key == SHOT_KEY then
      shot_key_released = true
   end
end

function lovr.keypressed(key)
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

function lovr.mousemoved(x, y, dx, dy)

end
