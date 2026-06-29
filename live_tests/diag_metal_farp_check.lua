return (function()
    local sm = CTLDSceneManager.getInstance()
    local cm = CTLDCrateManager._instance
    local results = {}
    local model = sm:getModel("Metal FARP")
    table.insert(results, "scene_model=" .. tostring(model ~= nil))
    if cm then
        local found = nil
        for w, entry in pairs(cm._weightIndex) do
            if entry.unit == "Metal FARP" then
                found = string.format("w=%.2f desc=%s", w, tostring(entry.desc))
                break
            end
        end
        table.insert(results, "weight_entry=" .. tostring(found))
        local inMenu = false
        for cat, catData in pairs(cm._processedCrates) do
            for _, pe in ipairs(catData.singleCrates or {}) do
                if pe.singleCrate and pe.singleCrate.unit == "Metal FARP" then
                    inMenu = true
                end
            end
        end
        table.insert(results, "in_processedCrates=" .. tostring(inMenu))
    else
        table.insert(results, "cm=nil")
    end
    return table.concat(results, " | ")
end)()
