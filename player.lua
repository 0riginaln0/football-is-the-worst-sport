local pl = {}
local machine = require "lib.statemachine"

--[[
TODO: Base collider, Move character
TODO: Actions, Action colliders
TODO:
]]


---comment
---@param world any
---@param x any
---@param y any
---@param z any
---@return table
function pl.createPlayer(world, x, y, z)
    x = x or 0
    y = y or 0
    z = z or 0

    local newplayer = {}
    newplayer.state_time = 0.0

    newplayer.stamina = 100
    newplayer.pass_fsm = machine.create {
        initial = 'not_passing',
        events = {
            { name = "pass",     from = "not_passing", to = "passing" },
            { name = "not_pass", from = "passing",     to = "not_passing" }
        }
    }
    newplayer.shot_fsm = machine.create {
        initial = "not_shooting",
        events = {
            { name = "charge",   from = "not_shooting", to = "charging" },
            { name = "release",  from = "charging",     to = "shooting" },
            { name = "end_shot", from = "shooting",     to = "not_shooting" }
        }
    }
    newplayer.ball_control_fsm = machine.create {
        initial = "controlling",
        events = {
            { name = "leave",   from = "controlling", to = "leaving" },
            { name = "control", from = "leaving",     to = "controlling" }
        }
    }
    newplayer.lock_fsm = machine.create {
        initial = "unlocked",
        events = {
            { name = "lock",   from = "unlocked", to = "locked" },
            { name = "unlock", from = "locked",   to = "unlocked" }
        }
    }
    newplayer.movement_fsm = machine.create {
        initial = "running",
        events = {
            { name = "jump",     from = "running",               to = "jumping" },
            { name = "land",     from = "jumping",               to = "running" },
            { name = "slide",    from = "running",               to = "sliding" },
            { name = "dive",     from = "running",               to = "diving" },
            { name = "stand_up", from = { "sliding", "diving" }, to = "standing_up" },
            { name = "run",      from = "standing_up",           to = "running" }
        }
    }

    newplayer.pos = {
        x = x, y = y, z = z
    }
    newplayer.model = lovr.graphics.newModel("res/player/footballer.gltf")

    function newplayer.updatePlayerPhysics(player, input)
        if input.spot then
            player.pos.x, player.pos.y, player.pos.z = input.spot.x, input.spot.y, input.spot.z
        end
    end

    return newplayer
end

---comment
---@param pass Pass
---@param player any
function pl.drawPlayer(pass, player)
    pass:setColor(0xaa0000)
    pass:draw(player.model, player.pos.x, player.pos.y + 0.8, player.pos.z, 0.017)
end

return pl
