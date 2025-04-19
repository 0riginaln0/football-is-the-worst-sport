# Great comeback!

Ok so my task for now is to document all the state of my game and split it up for the Client and Server parts. And then link them via ENet.

# Let's review what I have
## Imports
Everything starts from the `main.lua`
We are importing:

```lua
-- Client: `lovr.keyreleased`
lovr.window = require 'lib.lovr-window'
-- Client: `lovr.load`, 
-- Server: `lockMouse` (lovr.update)
lovr.mouse = require 'lib.lovr-mouse'
-- Client `lovr.load`, `lovr.draw`
local math = require 'math'
local lume = require 'lib.lume'
local dbg = require 'lib.debugger'
-- Client: globals
local newCam = require 'lib.cam'
-- Server: `lovr.update`
local tween = require 'lib.tween'
-- Client: `lovr.draw`
local phywire = require 'lib.phywire'
phywire.options.show_shapes = true     -- draw collider shapes (on by default)
phywire.options.show_velocities = true -- vector showing direction and magnitude of collider linear velocity
phywire.options.show_angulars = true   -- gizmo displaying the collider's angular velocity
phywire.options.show_joints = true     -- show joints between colliders
phywire.options.show_contacts = true   -- show collision contacts (quite inefficient, triples the needed collision computations)
phywire.options.wireframe = true
-- Client: `lovr.draw`
local cursor = require 'utils.cursor'
-- Server: `lovr.load`
local newPlayer = require 'player'
-- Client: `lovr.draw`
UI2D = require 'lib.ui2d.ui2d'
```

- Server imports:
```lua
local tween = require 'lib.tween'
local newPlayer = require 'player'
```

- Shared imports:
```lua
lovr.mouse = require 'lib.lovr-mouse'
```

## Gathering globals
Now lets look at global and local Constants & Variables

Client:
```lua
-- love.draw lovr.keyreleased
local track_cursor = true
```

Shared:
```lua
-- In player.lua
SLIDE_KEY = "a"
DIVE_KEY = "s"
JUMP_KEY = "d"
SHOT_KEY = 1
FAST_SHOT_KEY = 2

-- Server: lockMouse()
-- Client: lovr.resize()
WINDOW_WIDTH, WINDOW_HEIGHT = lovr.system.getWindowDimensions()

-- Server: updateCams(), update()
-- Client: draw()
local cam = newCam()
local turn_cam = newCam()

local space_just_pressed = false
local w_just_pressed = false
local x_just_pressed = false
local v_just_pressed = false
```

Server:
```lua
local cam_height = 0
local cam_tween_base = { value = 0 }
local cam_tween = nil
local cam_prev_rad_dt = 0

local world
local CONST_DT = 0.01666666666 -- my constant dt
local accumulator = 0          -- accumulator of time to simulate
local ground
local ball
local player
local BALL_RADIUS = 0.25
local INIT_BALL_POSITION = vec3(-1, 10, -1)

local K = 0.01 -- Adjust this constant based on the desired curve effect

local FULL_POWER_SHOT_CHARGE_TIME = 1.1

```


Oh my... That was horrible. Globals are bad. Lucky me, I have a chance to fix it during splitting it up to server and client.


But now I have to look deeper into server functions and document all the data it uses from server. Because atm there are a lot of calls for lovr.system.wasKeyPressed and e.t.c. in the server-side functions.

