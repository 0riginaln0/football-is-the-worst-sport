local machine = require 'lib.statemachine'
local lume = require 'lib.lume'
local dbg = require 'lib.debugger'

local FULL_POWER_SHOT_CHARGE_TIME = 1.1

local function newPlayer(world)
    local p = {}
    local PLAYER_INIT_POS = Vec3(0, 0, 0)
    local collider = world:newCapsuleCollider(PLAYER_INIT_POS, 0.4, 1.4)
    collider:setOrientation(math.pi / 2, 2, 0, 0)
    collider:setMass(10)
    collider:setTag("player")
    p.collider = collider
    p.collider:getShape():setUserData(p)
    p.last_vel = Vec3(0, 0, 0)
    p.jumped = false
    p.speed = 10
    p.timers = {
        slide_start = 0,
        slide_timeout = 2,
        dive_start = 0,
        dive_timeout = 1.5,
        jump_start = 0,
        jump_start_enough = 0.5,
        shot_start = 0,
        shot_timeout = 1,
        shot_charge_start = 0,
        shot_charge_finish = FULL_POWER_SHOT_CHARGE_TIME,
    }

    p.fsm = machine.create {
        initial = 'running',
        events = {
            { name = 'dive',      from = 'running', to = 'diving' },
            { name = 'dive_end',  from = 'diving',  to = 'running' },

            { name = 'jump',      from = 'running', to = 'jumping' },
            { name = 'jump_end',  from = 'jumping', to = 'running' },

            { name = 'slide',     from = 'running', to = 'sliding' },
            { name = 'slide_end', from = 'sliding', to = 'running' },
        },
        callbacks = {
            onslide = function()
                p.timers.slide_start = lovr.timer.getTime()
            end,
            ondive = function()
                p.timers.dive_start = lovr.timer.getTime()
            end,
            onjump = function()
                p.timers.jump_start = lovr.timer.getTime()
            end
        }
    }

    p.cursor_pos = Vec3(0, 0, 0)
    p.mouse_dir = Vec3(0, 0, 0)
    p.max_speed = 500
    p.min_speed = 0
    p.mouse_dir_max_len = 7
    p.mouse_dir_min_len = 1.5

    p.effective_dir = Vec3(0, 0, 0)

    p.shot_key_down = false
    p.fast_shot_key_down = false

    p.shot = Vec3(0, 0, 0)
    p.took_shot = false
    p.shooting = false

    p.charging = false
    p.shot_key_just_pressed = false
    p.shot_key_just_released = false
    p.shot_charge = 0

    function p.updatePlayerPhysics(player, CONST_DT)
        if player.fsm:is "running" then
            local curr_player_pos = vec3(player.collider:getPosition())
            local new_mouse_dir = player.cursor_pos - curr_player_pos
            player.mouse_dir.x = new_mouse_dir.x
            player.mouse_dir.y = new_mouse_dir.y
            player.mouse_dir.z = new_mouse_dir.z
            local mouse_dir_len = player.mouse_dir:length()
            local clamped_len =
                lume.clamp(mouse_dir_len, player.mouse_dir_min_len, player.mouse_dir_max_len)
            local t = (clamped_len - player.mouse_dir_min_len) /
                (player.mouse_dir_max_len - player.mouse_dir_min_len)
            local vel_magnitude = lume.lerp(player.min_speed, player.max_speed, t)
            local velocity = player.mouse_dir:normalize() * vel_magnitude

            local _, vy, _ = player.collider:getLinearVelocity()
            --#region shooting
            if player.shot_key_down or player.fast_shot_key_down then
                player.collider:setOrientation(math.pi / 2, 2, 0, 0)
                if player.fast_shot_key_down and not p.took_shot then
                    player.shooting = true
                    player.shot:set(player.mouse_dir:normalize() * clamped_len * 66)
                else
                    player.shooting = false
                end
                --endregion shooting
            else
                player.shooting = false
                player.last_vel:set(velocity:unpack())
                player.collider:setLinearVelocity(0, vy, 0)
                player.effective_dir:lerp(player.speed * velocity, 0.169) -- Lower -> smoother
                player.collider:applyLinearImpulse(player.effective_dir * CONST_DT)
                player.collider:setOrientation(math.pi / 2, 2, 0, 0)
            end
        elseif player.fsm:is "sliding" then
        elseif player.fsm:is "diving" then
        elseif player.fsm:is "jumping" then
            if not player.jumped then
                local curr_player_pos = vec3(player.collider:getPosition())
                local new_mouse_dir = player.cursor_pos - curr_player_pos
                player.mouse_dir.x = new_mouse_dir.x
                player.mouse_dir.y = new_mouse_dir.y
                player.mouse_dir.z = new_mouse_dir.z
                local v = vec3(player.collider:getLinearVelocity())
                player.collider:setLinearVelocity(0, v.y, 0)
                local velocity = player.mouse_dir:normalize() * player.last_vel:length()
                player.collider:applyLinearImpulse(player.speed * velocity * CONST_DT)
                player.collider:setOrientation(math.pi / 2, 2, 0, 0)
                player.collider:applyLinearImpulse(0, 50, 0)
                player.jumped = true
            end
            player.collider:setOrientation(math.pi / 2, 2, 0, 0)

            --#region shooting
            local curr_player_pos = vec3(player.collider:getPosition())
            local new_mouse_dir = player.cursor_pos - curr_player_pos
            player.mouse_dir.x = new_mouse_dir.x
            player.mouse_dir.y = new_mouse_dir.y
            player.mouse_dir.z = new_mouse_dir.z
            local mouse_dir_len = player.mouse_dir:length()
            local clamped_len = lume.clamp(
                mouse_dir_len, player.mouse_dir_min_len, player.mouse_dir_max_len
            )
            if player.shot_key_down or player.fast_shot_key_down then
                player.collider:setOrientation(math.pi / 2, 2, 0, 0)
                if player.fast_shot_key_down and not p.took_shot then
                    player.shooting = true
                    player.shot:set(player.mouse_dir:normalize() * clamped_len * 66)
                else
                    player.shooting = false
                end
            else
                player.shooting = false
            end
            --#endregion shooting
        end
    end

    function p.updatePlayer(player)
        local new_shot_key_down = lovr.mouse.isDown(SHOT_KEY)
        if not player.shot_key_down and new_shot_key_down then
            player.shot_key_just_pressed = true
        end
        if player.shot_key_down and new_shot_key_down then
            player.shot_key_just_pressed = false
        end
        if player.shot_key_down and not new_shot_key_down then
            player.shot_key_just_released = true
        end
        if not player.shot_key_down and not new_shot_key_down then
            player.shot_key_just_released = false
        end

        player.shot_key_down      = new_shot_key_down
        player.fast_shot_key_down = lovr.mouse.isDown(FAST_SHOT_KEY)
        local time                = lovr.timer.getTime()
        if player.shot_key_just_pressed then
            -- print("START CHARGING")
            player.timers.shot_charge_start = time
            player.timers.shot_charge_finish = time + FULL_POWER_SHOT_CHARGE_TIME
            player.charging = true
        end
        if player.shot_key_down then
            local charge_percentage
            local time_elapsed = (time - player.timers.shot_charge_start)
            if time_elapsed < FULL_POWER_SHOT_CHARGE_TIME then
                charge_percentage = time_elapsed / FULL_POWER_SHOT_CHARGE_TIME
            else
                charge_percentage = 1
            end

            -- print(charge_percentage)
            player.shot_charge = charge_percentage
        end
        if player.shot_key_just_released then
            -- print("SHOTT!!")
            player.shooting = true
            player.charging = false
        end

        if player.fsm:is "running" then
            if lovr.system.wasKeyPressed(SLIDE_KEY) then
                player.fsm:slide()
            elseif lovr.system.wasKeyPressed(DIVE_KEY) then
                player.fsm:dive()
            elseif lovr.system.wasKeyPressed(JUMP_KEY) then
                player.fsm:jump()
            end

            if player.took_shot and (time - player.timers.shot_start > player.timers.shot_timeout) then
                player.took_shot = false
            end
        elseif player.fsm:is "sliding" then
            if time - player.timers.slide_start > player.timers.slide_timeout then
                player.fsm:slide_end()
            end
        elseif player.fsm:is "diving" then
            if time - player.timers.dive_start > player.timers.dive_timeout then
                player.fsm:dive_end()
            end
        elseif player.fsm:is "jumping" then
            local p_shape = player.collider:getShape()
            local x, y, z, angle, ax, ay, az = player.collider:getPose()
            local ground_hit = world:overlapShape(p_shape, x, y, z, angle, ax, ay, az, 0.1, "ground")
            if player.jumped and (time - player.timers.jump_start > player.timers.jump_start_enough) then
                if ground_hit then
                    player.fsm:jump_end()
                    player.jumped = false
                end
            end
        end
    end

    return p
end

return newPlayer
