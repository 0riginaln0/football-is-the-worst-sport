local m = {}
---
--- Copies the coordinates from one 3D vector to another.
---
--- This function takes a table containing two vectors, `from` and `into`,
--- and copies the x, y, and z coordinates from the `from` vector to the `into` vector.
---
---@param vecs { from: vec3, into: vec3 }
function m.copyVec3(vecs)
    vecs.into.x, vecs.into.y, vecs.into.z = vecs.from.x, vecs.from.y, vecs.from.z
end

return m
