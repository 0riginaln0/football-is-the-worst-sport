local function newCam()
    local m = {}

    m.fov = math.pi / 2 -- math.pi / 4 if "isometric-like" look is needed
    m.near_plane = 0.01

    m.upvector = Vec3(0, 1, 0)
    m.position = Vec3(0, 3, 4)
    m.center = Vec3(0, 0, 0)

    m.zoom_speed = 1.0
    m.orbit_speed = 1.0
    m.pan_speed = 1.0

    m.azimuth = math.pi / 2
    m.radius = m.position:distance(m.center)
    m.polar = math.acos((m.position.y - m.center.y) / m.radius)

    -- angles are measured from the up vector
    m.polar_upper = 0.1
    m.polar_lower = math.pi - m.polar_upper

    m.radius_lower = 0.1

    -- these are read-only; overwriten in nudge() and resize()
    m.pose = Mat4():target(m.position, m.center, m.upvector)
    m.projection = Mat4():perspective(m.fov, 1, m.near_plane, 0)

    -- should be called on top of lovr.draw()
    function m.setCamera(self, pass)
        pass:setViewPose(1, self.pose)
        pass:setProjection(1, self.projection)
    end

    -- make relative changes to camera position
    function m.nudge(self, delta_azimuth, delta_polar, delta_radius)
        delta_azimuth   = delta_azimuth or 0
        delta_polar     = delta_polar or 0
        delta_radius    = delta_radius or 0
        self.azimuth    = self.azimuth + delta_azimuth
        self.polar      = math.max(self.polar_upper, math.min(self.polar_lower, self.polar + delta_polar))
        self.radius     = math.max(self.radius_lower, self.radius + delta_radius)
        self.position.x = self.center.x + self.radius * math.sin(self.polar) * math.cos(self.azimuth)
        self.position.y = self.center.y + self.radius * math.cos(self.polar)
        self.position.z = self.center.z + self.radius * math.sin(self.polar) * math.sin(self.azimuth)
        self.pose:target(self.position, self.center, self.upvector)
    end

    -- should be called from lovr.resize()
    function m.resize(self, width, height)
        local aspect = width / height
        self.projection = Mat4():perspective(self.fov, aspect, self.near_plane, 0)
    end

    m:resize(lovr.system.getWindowDimensions())

    function m.incrementFov(self, inc)
        self.fov = self.fov + inc
        self:resize(lovr.system.getWindowDimensions())
    end

    -- should be called from lovr.mousemoved()
    function m.mousemoved(self, x, y, dx, dy)
        if lovr.system.isMouseDown(3) then
            if lovr.system.isMouseDown(1) then
                self.center.y = self.center.y + self.pan_speed * 0.01 * dy
            else
                local view           = mat4(self.pose):invert()
                local camera_right   = vec3(view[1], view[5], view[9])
                local camera_forward = vec3(view[2], 0, view[10]):normalize()
                self.center:add(camera_right * (self.pan_speed * 0.005 * -dx))
                self.center:add(camera_forward * (self.pan_speed * 0.005 * dy))
            end
            self:nudge()
        elseif lovr.system.isMouseDown(1) then
            self:nudge(self.orbit_speed * 0.0025 * dx, self.orbit_speed * 0.0025 * -dy, 0)
        end
    end

    -- should be called from lovr.wheelmoved()
    function m.wheelmoved(self, dx, dy)
        self:nudge(0, 0, -dy * self.zoom_speed * 0.12)
    end

    function m.getLookVector(self)
        return self.center - self.position
    end

    -- quick way to start using camera module - just call this function
    function m.integrate()
        local stub_fn = function() end
        local existing_cb = {
            draw = lovr.draw or stub_fn,
            resize = lovr.resize or stub_fn,
            mousemoved = lovr.mousemoved or stub_fn,
            wheelmoved = lovr.wheelmoved or stub_fn,
        }
        local function wrap(callback)
            return function(...)
                m[callback](...)
                existing_cb[callback](...)
            end
        end
        lovr.mousemoved = wrap('mousemoved')
        lovr.wheelmoved = wrap('wheelmoved')
        lovr.resize = wrap('resize')
        ---@diagnostic disable-next-line: duplicate-set-field
        lovr.draw = function(pass)
            m.setCamera(pass)
            existing_cb.draw(pass)
        end
    end

    return m
end

return newCam
