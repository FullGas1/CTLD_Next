-- Check if any static ending in MG_1 still exists
local found = {}
local vol = { id = world.VolumeType.SPHERE, params = { point = {x=0,y=0,z=0}, radius = 999999 } }
world.searchObjects(Object.Category.STATIC, vol, function(obj)
    if obj and obj:isExist() then
        local name = obj:getName() or ""
        if name:sub(-4) == "MG_1" then
            local pos = obj:getPoint()
            found[#found+1] = string.format("%s @ (%.0f, %.0f)", name, pos.x, pos.z)
        end
    end
    return true
end)
local direct = StaticObject.getByName("CTLD_Humvee_-_MG_1")
if direct and direct:isExist() then
    found[#found+1] = "DIRECT: CTLD_Humvee_-_MG_1 EXISTS"
end
if #found == 0 then
    trigger.action.outText("[CHECK] MG_1: aucun static trouve — DISPARU", 8)
    return "GONE"
else
    trigger.action.outText("[CHECK] MG_1 TROUVE:\n" .. table.concat(found, "\n"), 10)
    return table.concat(found, " | ")
end
