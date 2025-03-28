local m = {}

--- Copies the coordinates from one 3D vector to another.
---
--- This function takes a table containing two vectors, `from` and `into`,
--- and copies the x, y, and z coordinates from the `from` vector to the `into` vector.
---
---@param from Vec3
---@param into Vec3
function m.copyVec3(from, into)
    into.x, into.y, into.z = from.x, from.y, from.z
end

return m
