---@diagnostic disable
-- diag_countryside_farp_registration.lua
-- Vérifie que la scène Countryside FARP est bien enregistrée après migration vers src/scenes/

local sm     = CTLDSceneManager.getInstance()
local model  = sm:getModel("Countryside FARP")
local models = {}
for k in pairs(sm._models) do models[#models+1] = k end
table.sort(models)

local lines = {
    "=== Countryside FARP — post-migration check ===",
    "scene 'Countryside FARP' registered: " .. tostring(model ~= nil),
    "scene stepCount: " .. tostring(model and #model.steps or "N/A"),
    "all registered scenes (" .. #models .. "): " .. table.concat(models, ", "),
}

-- Vérifier que FARP Alpha est toujours là (non impacté)
local farpAlpha = sm:getModel("FARP Alpha")
lines[#lines+1] = "scene 'FARP Alpha' still registered: " .. tostring(farpAlpha ~= nil)

local msg = table.concat(lines, "\n")
trigger.action.outText(msg, 30)
env.info("[DIAG_CS] " .. msg:gsub("\n", " | "))
return msg
