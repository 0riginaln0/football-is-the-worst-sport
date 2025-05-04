local pl = {}

--[[
TODO: Base collider, Move character
TODO: Actions, Action colliders
TODO:
]]


-- union
PlayerState = {
    PlayerStateNormal,
    PlayerStateJumping,
    PlayerStateSliding,
    PlayerStateDiving,
}

---@class Player
---@field bar string
---@field bodyCollider Collider
---@field slideCollider Collider

---@type Player
Player = {
    pos = vec3(),
    vel = vec3(),
    state = PlayerState,
    state_time = 0.0,
}

function pl.new()
    return {

    }
end

function pl.update(player)

end

return pl
