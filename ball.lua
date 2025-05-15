local b = {}
local machine = require "statemachine"


local constants = {
    ball_radius = 0.25 / 2
}

---comment
---@param world World
---@param x any
---@param y any
---@param z any
---@return table
function b.createBall(world, x, y, z)
    x = x or 0
    y = y or 0
    z = z or 0

    local newball = {}

    newball.control_fsm = machine.create {
        initial = 'uncontrolled',
        events = {
            { name = 'acquire', from = 'uncontrolled', to = 'controlled' },
            { name = 'release', from = 'controlled',   to = 'uncontrolled' },
        }
    }
    newball.model = lovr.graphics.newModel("res/ball/football_ball.gltf") -- TODO disable if NO_DRAW mode is enabled
    newball.collider = world:newSphereCollider(x, y, z, constants.ball_radius)
    newball.collider:setRestitution(0.7)
    newball.collider:setFriction(0.7)
    newball.collider:setLinearDamping(0.3)
    newball.collider:setAngularDamping(0.7)
    newball.collider:setMass(0.44)
    newball.collider:setContinuous(true)
    newball.collider:setTag("ball")

    newball.area = world:newCylinderCollider(x, y, z, constants.ball_radius * 3, 0.04)
    newball.area:setKinematic(true)
    newball.area:setOrientation(math.pi / 2, 2, 0, 0)
    newball.area:setTag("ball-area")
    newball.area:getShape():setUserData(newball)

    newball.kicked_by = nil      -- checks to apply torque
    newball.state_time = 0
    newball.last_time_kicked = 0 -- checks to apply torque

    return newball
end

---comment
---@param pass Pass
---@param ball any
function b.drawBall(pass, ball)
    local x, y, z, angle, ax, ay, az = ball.collider:getPose()
    ball.area:setPosition(x, y, z)
    local scale = 0.5
    pass:draw(ball.model, x, y, z, scale, angle, ax, ay, az)
end

---comment
---@param ball_collider Collider
---@param K number
---@return number xForce
---@return number yForce
---@return number zForce
function b.calculateMagnusForce(ball_collider, K)
    -- Get the ball's spin (ω)
    local angular_vx, angular_vy, angular_vz = ball_collider:getAngularVelocity()
    -- Get the ball's velocity (v)
    local linear_vx, linear_vy, linear_vz = ball_collider:getLinearVelocity()
    -- Calculate the cross product ω × v
    local magnusX = angular_vy * linear_vz - angular_vz * linear_vy
    local magnusY = angular_vz * linear_vx - angular_vx * linear_vz
    local magnusZ = angular_vx * linear_vy - angular_vy * linear_vx
    -- Scale the Magnus force by the constant K
    return magnusX * K, magnusY * K, magnusZ * K
end

return b
