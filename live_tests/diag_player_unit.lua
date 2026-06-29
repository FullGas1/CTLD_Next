---@diagnostic disable
local r = {}
for _, coa in ipairs({1, 2}) do
    local groups = coalition.getGroups(coa, Group.Category.HELICOPTER)
    for _, g in ipairs(groups or {}) do
        for _, u in ipairs(g:getUnits() or {}) do
            r[#r+1] = string.format("coa=%d grp=%s unit=%s alive=%s",
                coa, g:getName(), u:getName(), tostring(u:isExist()))
        end
    end
end
return #r > 0 and table.concat(r, " | ") or "no helicopter units found"
