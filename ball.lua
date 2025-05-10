local b = {}

function b.createBall(world, x, y, z)
    x = x or 0
    y = y or 0
    z = z or 0

    local newball = {}
    newball.model = lovr.graphics.newModel("res/ball/football_ball.gltf")
    newball.collider = world:newSphereCollider(x, y, z, 0.25)
    newball.collider:setRestitution(0.7)
    newball.collider:setFriction(0.7)
    newball.collider:setLinearDamping(0.3)
    newball.collider:setAngularDamping(0.7)
    newball.collider:setMass(0.44)
    newball.collider:setContinuous(true)
    newball.collider:setTag("ball")
    newball.area = world:newCylinderCollider(x, y, z, 0.25 * 3, 0.04)
    newball.area:setKinematic(true)
    newball.area:setOrientation(math.pi / 2, 2, 0, 0)
    newball.area:setTag("ball-area")
    newball.area:getShape():setUserData(newball)

    return newball
end

function b.drawBall(pass, ball)
    local x, y, z, angle, ax, ay, az = ball.collider:getPose()
    ball.area:setPosition(x, y, z)
    local scale = 1
    pass:draw(ball.model, x, y, z, scale, angle, ax, ay, az)
end

return b
