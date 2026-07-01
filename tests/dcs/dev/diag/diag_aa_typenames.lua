-- diag_aa_typenames.lua
-- Validate every DCS unit typename referenced in AA system templates and
-- spawnableCrates descriptors. Tries to spawn each type as a 1-unit group
-- at the player's current position + 200m, then immediately destroys it.
-- Results logged to dcs.log as [AA_TYPES] lines.
--
-- Run while in a mission with at least one player unit on the map.
-- Read results in dcs.log: PASS = typename is valid, FAIL = unknown type.

local TAG  = "[AA_TYPES]"
local DIST = 200   -- spawn test distance from test origin

-- ── find a reference point (any player unit, or world origin fallback) ────
local testOrigin = { x = 0, y = 0, z = 0 }
for _, side in ipairs({ coalition.side.BLUE, coalition.side.RED }) do
    local units = coalition.getPlayers(side) or {}
    if units[1] and units[1]:isExist() then
        local p = units[1]:getPoint()
        testOrigin = { x = p.x + DIST, y = p.y, z = p.z + DIST }
        break
    end
end

-- ── helpers ──────────────────────────────────────────────────────────────
local uid = 90000
local function _nextId() uid = uid + 1; return uid end

local function _trySpawn(typeName, coa)
    local id    = _nextId()
    local cId   = (coa == coalition.side.RED) and country.id.RUSSIA or country.id.USA
    local gdata = {
        ["visible"]    = false,
        ["task"]       = "Ground Nothing",
        ["route"]      = { ["points"] = {} },
        ["groupId"]    = id,
        ["hidden"]     = false,
        ["units"]      = {
            [1] = {
                ["x"]          = testOrigin.x,
                ["y"]          = testOrigin.z,
                ["type"]       = typeName,
                ["unitId"]     = id,
                ["heading"]    = 0,
                ["playerCanDrive"] = false,
                ["skill"]      = "Average",
                ["name"]       = "CTLD_DIAG_" .. id,
            },
        },
        ["y"]   = testOrigin.z,
        ["x"]   = testOrigin.x,
        ["name"] = "CTLD_DIAG_GRP_" .. id,
        ["start_time"] = 0,
    }
    local ok = pcall(function() coalition.addGroup(cId, Group.Category.GROUND, gdata) end)
    if ok then
        local g = Group.getByName("CTLD_DIAG_GRP_" .. id)
        if g and g:isExist() then
            g:destroy()
            return true
        end
    end
    return false
end

-- ── collect types to test ─────────────────────────────────────────────────
local toTest = {}   -- { typeName, label, coalition }

-- From AA templates (class-level field, not instance)
local aaMgr = CTLDCrateAssemblyManager.getInstance()
for _, tmpl in ipairs(CTLDCrateAssemblyManager.TEMPLATES or {}) do
    local coa = (tmpl.side == 1) and coalition.side.RED or coalition.side.BLUE
    for _, part in ipairs(tmpl.parts or {}) do
        toTest[#toTest+1] = { t = part.name, label = tmpl.name .. "/" .. part.name, coa = coa }
    end
    if tmpl.repair then
        toTest[#toTest+1] = { t = tmpl.repair, label = tmpl.name .. "/repair", coa = coa }
    end
end

-- From spawnableCrates descriptors (non-multiple, non-AA)
local aaMgrRef = aaMgr
local spawnableCrates = ctld.gs("spawnableCrates") or {}
for cat, crates in pairs(spawnableCrates) do
    for _, cr in ipairs(crates) do
        if cr.unit and not cr.multiple then
            -- Skip if already an AA part
            local isAA = aaMgrRef:getTemplateForUnit(cr.unit) ~= nil
            if not isAA then
                local coa = (cr.side == 1) and coalition.side.RED or coalition.side.BLUE
                toTest[#toTest+1] = { t = cr.unit, label = cat .. "/" .. cr.desc, coa = coa }
            end
        end
    end
end

-- ── run tests ─────────────────────────────────────────────────────────────
local pass, fail = 0, 0
local lines = { TAG .. " typename validation (" .. #toTest .. " entries):" }

for _, entry in ipairs(toTest) do
    local ok = _trySpawn(entry.t, entry.coa)
    if ok then
        pass = pass + 1
        lines[#lines+1] = string.format("  PASS  %-40s  [%s]", entry.t, entry.label)
    else
        fail = fail + 1
        lines[#lines+1] = string.format("  FAIL  %-40s  [%s]  ← INVALID typename", entry.t, entry.label)
    end
end

lines[#lines+1] = string.format("%s RESULT: %d PASS / %d FAIL", TAG, pass, fail)
env.info(table.concat(lines, "\n"))
