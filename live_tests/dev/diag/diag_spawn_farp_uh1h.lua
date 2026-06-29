---@diagnostic disable
-- diag_spawn_farp_uh1h.lua
-- Spawn FARP Alpha scene relative to UH-1H-1 for visual diagnosis of crate/object positioning.
-- Returns the scene name and reference position snapshot.

local u = Unit.getByName("uh1-1")
if not u or not u:isExist() then
    return "ERROR: UH-1H-1 not found or dead"
end

local pt  = u:getPoint()
local hdg = ctld.utils.getHeadingInRadians("diag_farp", u, true)

local sm = CTLDSceneManager.getInstance()
local scene = sm:playScene(u, "FARP Alpha", nil, nil)
if not scene then
    return "ERROR: playScene returned nil — check CTLDSceneManager log"
end

return string.format(
    "FARP Alpha started: scene=%s | refX=%.1f refZ=%.1f alt=%.1f hdgDeg=%.1f",
    scene._name,
    pt.x, pt.z, pt.y,
    math.deg(hdg)
)
