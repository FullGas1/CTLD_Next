---@diagnostic disable
-- =============================================================================
-- tests/dcs/util/inject_troop_templates.lua
-- Utility: register minimal troop templates for test missions
--
-- Injects 3 templates covering typical AI-transport scenarios (MT-07, MT-11, ai_troops):
--   - "Infantry Squad"     : 4 inf (BLUE only)
--   - "Anti-Tank Team"     : 2 inf + 2 at (both sides)
--   - "JTAC Team"          : 2 inf + 1 jtac (BLUE only)
--
-- Inject once before any scenario requiring CTLDTroopManager._templates.
-- Idempotent: skips templates already registered.
-- =============================================================================

if not ctld or not ctld.utils then
    trigger.action.outText("[inject_templates] ABORT: CTLD not initialized.", 10)
    return Witchcraft
end

local TAG = "[inject_templates]"
local function log(msg) ctld.utils.log("INFO", TAG .. " " .. msg) end

local tm = CTLDTroopManager.getInstance()
local added = 0

local templates = {
    { name = "Infantry Squad",  composition = { inf = 4 },           side = coalition.side.BLUE },
    { name = "Anti-Tank Team",  composition = { inf = 2, at = 2 },   side = nil },
    { name = "JTAC Team",       composition = { inf = 2, jtac = 1 }, side = coalition.side.BLUE },
}

for _, cfg in ipairs(templates) do
    local ok, err = tm:createLoadableGroup(cfg)
    if ok then
        added = added + 1
        log("registered: " .. cfg.name)
    else
        log("skipped: " .. cfg.name .. " (" .. tostring(err) .. ")")
    end
end

log(string.format("done — %d template(s) added, total=%d", added, #tm._templates))
trigger.action.outText(TAG .. " " .. added .. " template(s) added — total=" .. #tm._templates, 5)
return Witchcraft
