-- diag_farp_invisible_bbox.lua
-- Gets the bounding box of the "Farp Invisible-1" static placed in the mission.
local name = "Farp Invisible-1"
local obj = StaticObject.getByName(name)
if not obj then
    return "StaticObject '" .. name .. "' not found"
end

local bb = obj:getBoundingBox()
local pt = obj:getPoint()
local pos = obj:getPosition()  -- {p, x (fwd), y (up), z (right)}

return string.format(
    "pos=(%.1f,%.1f,%.1f) | bbox min=(%.2f,%.2f,%.2f) max=(%.2f,%.2f,%.2f) | fwd=(%.3f,%.3f,%.3f)",
    pt.x, pt.y, pt.z,
    bb.min.x, bb.min.y, bb.min.z,
    bb.max.x, bb.max.y, bb.max.z,
    pos.x.x, pos.x.y, pos.x.z
)
