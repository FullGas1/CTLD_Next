-- diag_set_cratesRequired_1.lua
-- DEBUG ONLY — sets cratesRequired=1 for all "Both" scene crates (FOB, FARP Alpha, Countryside FARP, mineField).
-- Patches CTLDSceneManager models + CTLDCrateManager _weightIndex in-memory.
-- Inject via Witchcraft after CTLD_Next.lua is loaded.

-- "fobScene" = ancien nom avant fix ; "FOB" = nom corrigé après rebuild
local scenesToPatch = { "FOB", "fobScene", "FARP Alpha", "Countryside FARP", "mineField" }

local sm  = CTLDSceneManager.getInstance()
local cm  = CTLDCrateManager.getInstance()
local patched = {}

for _, name in ipairs(scenesToPatch) do
    local model = sm:getModel(name)
    if model and model.crate then
        model.crate.cratesRequired = 1
        -- Patch _weightIndex entry as well
        if cm._weightIndex then
            for _, entry in pairs(cm._weightIndex) do
                if entry.unit == name then
                    entry.cratesRequired = 1
                end
            end
        end
        table.insert(patched, name)
    end
end

local msg = "[DEBUG] cratesRequired=1 patched for: " .. table.concat(patched, ", ")
trigger.action.outText(msg, 10)
return msg
